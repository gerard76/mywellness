require "json"
require "zip"

class WorkoutImporter
  attr_reader :new_count, :updated_count

  def initialize
    @new_count     = 0
    @updated_count = 0
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

      machine = machines_cache[ph_id] ||= Machine.find_or_create_by!(ph_id: ph_id)
      ws = machine.workout_sessions.find_or_initialize_by(workout_date: date_str)
      if ws.new_record?
        ws.update!(rm1: rm1, total_iso_weight: tiw)
        @new_count += 1
      elsif rm1 > ws.rm1
        ws.update!(rm1: rm1, total_iso_weight: tiw)
        @updated_count += 1
      end
    end
  end
end
