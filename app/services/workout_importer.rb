require "json"
require "zip"

class WorkoutImporter
  # Mywellness sends localised biometric labels, so we key on the language
  # independent `type` and translate to the names already stored in the database.
  BIOMETRIC_TYPES = {
    "UserWeight"         => "Weight",
    "MuscleMass"         => "Muscle Mass",
    "FatMass"            => "Fat Mass",
    "BMI"                => "BMI",
    "FatMassPercentace"  => "Fat mass Perc", # their spelling, not ours
    "TotalBodyWater"     => "Total Body Water",
    "TotalBodyWaterPerc" => "Total Body Water Perc",
    "UserHeight"         => "Height",
    "TrainingExpertise"  => "Training expertise",
  }.freeze

  attr_reader :new_count, :updated_count, :biometric_count

  def initialize
    @new_count       = 0
    @updated_count   = 0
    @biometric_count = 0
  end

  # Import one workout as returned by MywellnessApi#workout. Each exercise in a
  # workout is one machine; a machine can appear several times (one per set), and
  # upsert_session keeps the best Rm1 for the day.
  #
  # A workout lists every exercise in the programme, including ones that were
  # skipped (a broken machine, say). Rm1 is a stored reference value and is
  # present either way, so `doneProperties` is what proves the set happened.
  def import_workout(workout)
    date = workout["startedOn"].to_s.first(10)
    return self if date.blank?

    machines_cache = {}
    (workout["exercises"] || []).each do |exercise|
      next if exercise["doneProperties"].blank?

      ph_id = exercise["physicalActivityId"]
      tiw   = named_value(exercise["doneProperties"], "TotalIsoWeight")
      rm1   = estimated_rm1(exercise, tiw)
      next unless ph_id.present? && rm1 && rm1 > 0

      upsert_session(machines_cache, ph_id, date, rm1, tiw)
    end
    self
  end

  # Import measurements as returned by MywellnessApi#last_biometrics.
  def import_biometric_measurements(measurements)
    (measurements || []).each do |measurement|
      name        = BIOMETRIC_TYPES[measurement["type"]]
      measured_on = measurement["measuredOn"].to_s.first(10)
      next if name.blank? || measured_on.blank? || measurement["value"].nil?

      record = Biometric.find_or_initialize_by(name: name, measured_on: measured_on)
      next unless record.new_record?

      record.update!(value: measurement["value"].to_f)
      @biometric_count += 1
    end
    self
  end

  def import_zip(zip_path)
    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        next unless entry.name.end_with?(".json")
        base = File.basename(entry.name)
        if base.start_with?("indooractivities")
          import_json_data(entry.get_input_stream.read)
        elsif base.start_with?("biometrics")
          import_biometrics_data(entry.get_input_stream.read)
        end
      end
    end
    self
  end

  def import_json(content)
    raw = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    parsed = JSON.parse(raw)
    if parsed.is_a?(Array) && parsed.first&.key?("measuredOn")
      import_biometrics_data(content)
    else
      import_json_data(content)
    end
    self
  end

  private

  def import_biometrics_data(raw)
    entries = JSON.parse(raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?"))
    return unless entries.is_a?(Array)

    entries.each do |e|
      name        = e["name"]
      measured_on = e["measuredOn"]&.first(10)
      value       = e["value"].to_f
      next unless name && measured_on

      Biometric.find_or_create_by!(name: name, measured_on: measured_on) do |b|
        b.value = value
      end
    end
  end

  def import_json_data(raw)
    sessions = JSON.parse(raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?"))
    return unless sessions.is_a?(Array)

    machines_cache = {}
    sessions.each do |s|
      ph_id = s["phId"]
      next unless ph_id

      performed = s.dig("performedData", "pr") || []
      rm1       = performed.find { |p| p["n"] == "Rm1" }&.dig("v")
      tiw       = performed.find { |p| p["n"] == "TotalIsoWeight" }&.dig("v")
      next unless rm1 && rm1 > 0

      date_str = s["on"]&.first(10)
      next unless date_str

      upsert_session(machines_cache, ph_id, date_str, rm1, tiw)
    end
  end

  # One row per machine per day, keeping the heaviest Rm1 that day.
  def upsert_session(machines_cache, ph_id, date_str, rm1, tiw)
    machine = machines_cache[ph_id] ||= Machine.find_or_create_by!(ph_id: ph_id)
    ws      = machine.workout_sessions.find_or_initialize_by(workout_date: date_str)

    if ws.new_record?
      ws.update!(rm1: rm1, total_iso_weight: tiw)
      @new_count += 1
    elsif rm1 > ws.rm1
      ws.update!(rm1: rm1, total_iso_weight: tiw)
      @updated_count += 1
    end
  end

  def named_value(collection, name)
    (collection || []).find { |item| item["name"] == name }&.dig("value")
  end

  # The one-rep max for the set actually performed, via Epley:
  #
  #   1RM = weight * (1 + reps / 30)
  #
  # Do not reach for userReferenceValues["Rm1"] here. That is the 1RM stored on
  # the profile from the last max test, identical on every set until retested,
  # and using it flatlines the chart. Reps are not reported directly, but the
  # machine gives total weight lifted and the weight per rep.
  def estimated_rm1(exercise, total_iso_weight)
    weight = named_value(exercise["propertyCounters"], "IsoWeight")
    return nil unless weight && weight > 0 && total_iso_weight

    reps = total_iso_weight / weight
    return nil unless reps >= 1

    weight * (1 + reps / 30.0)
  end
end
