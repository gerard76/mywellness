class HomeController < ApplicationController
  # On this day the machines ran a one-rep max test instead of the usual sets, so
  # the numbers are real but two to four times a normal session and they flatten
  # every chart. Kept in the database, left out of the graphs.
  MAX_TEST_DATES = [Date.new(2026, 3, 2)].freeze

  BIOMETRIC_UNITS = {
    "Weight"           => "kg",
    "Muscle Mass"      => "kg",
    "Muscle Mass Perc" => "%",
    "Fat Mass"         => "kg",
    "BMI"              => "",
    "Fat mass Perc"    => "%"
  }.freeze

  def index
    @notice  = params[:notice]
    @alert   = params[:alert]

    stored_names = BIOMETRIC_UNITS.keys - ["Muscle Mass Perc"]
    biometrics = Biometric.where(name: stored_names).order(:measured_on)
    @biometrics_data = biometrics.group_by(&:name).map do |name, records|
      {
        name:  name,
        unit:  BIOMETRIC_UNITS[name] || "",
        data:  records.map { |b| { date: b.measured_on.to_s, value: b.value.round(2) } }
      }
    end

    weight_by_date  = @biometrics_data.find { |d| d[:name] == "Weight" }&.dig(:data)&.index_by { |p| p[:date] } || {}
    muscle_by_date  = @biometrics_data.find { |d| d[:name] == "Muscle Mass" }&.dig(:data)&.index_by { |p| p[:date] } || {}
    muscle_pct_data = (weight_by_date.keys & muscle_by_date.keys).sort.filter_map do |date|
      w = weight_by_date[date][:value]
      m = muscle_by_date[date][:value]
      next unless w && w > 0
      { date: date, value: (m / w * 100).round(1) }
    end
    unless muscle_pct_data.empty?
      @biometrics_data.insert(
        @biometrics_data.index { |d| d[:name] == "Muscle Mass" }.to_i + 1,
        { name: "Muscle Mass Perc", unit: "%", data: muscle_pct_data }
      )
    end

    biometric_names = BIOMETRIC_UNITS.keys
    @biometrics_data.sort_by! { |d| biometric_names.index(d[:name]) || 999 }
    @bio_start_date = @biometrics_data.filter_map { |d| d[:data].first&.dig(:date) }.max
    @latest_biometrics = @biometrics_data.each_with_object({}) do |d, h|
      latest   = d[:data].last
      baseline = d[:data].find { |p| @bio_start_date.nil? || p[:date] >= @bio_start_date }
      change   = latest && baseline && latest != baseline ? (latest[:value] - baseline[:value]).round(2) : nil
      pct      = change && baseline[:value] != 0 ? (change / baseline[:value] * 100).round(1) : nil
      h[d[:name]] = latest&.merge(change: change, pct_change: pct, since: baseline&.dig(:date))
    end

    sessions = WorkoutSession.joins(:machine)
                             .select("workout_sessions.*, machines.name as machine_name, machines.muscle_group, machines.ph_id")
                             .order(:workout_date)
                             .to_a

    # Every training day, including the max test - it was a workout.
    @workout_dates = sessions.map { |s| s.workout_date.to_s }.uniq.sort

    grouped = sessions.reject { |s| MAX_TEST_DATES.include?(s.workout_date) }.group_by(&:ph_id)

    @chart_data = grouped.map do |ph_id, ws|
      machine = ws.first
      {
        name:         machine.machine_name.presence || ph_id.first(8),
        named:        machine.machine_name.present?,
        muscle_group: machine.muscle_group || "Other",
        data:         ws.map { |s| { date: s.workout_date.to_s, rm1: s.rm1.round(1) } }
      }
    end.sort_by { |d| [d[:muscle_group], d[:name]] }

    @progress = @chart_data.map do |d|
      next if d[:data].size < 2
      dates = d[:data].map { |p| p[:date] }.uniq.sort
      baseline_date = dates[0]
      baseline = d[:data].select { |p| p[:date] == baseline_date }.max_by { |p| p[:rm1] }
      latest   = d[:data].last
      next unless baseline && latest && baseline[:date] != latest[:date]
      change = ((latest[:rm1] - baseline[:rm1]) / baseline[:rm1] * 100).round(1)
      { name: d[:name], muscle_group: d[:muscle_group],
        baseline: baseline, latest: latest, pct_change: change }
    end.compact.sort_by { |p| -p[:pct_change] }
  end
end
