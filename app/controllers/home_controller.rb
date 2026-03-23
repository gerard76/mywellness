class HomeController < ApplicationController
  def index
    @notice  = params[:notice]
    @alert   = params[:alert]

    sessions = WorkoutSession.joins(:machine)
                             .select("workout_sessions.*, machines.name as machine_name, machines.muscle_group, machines.ph_id")
                             .order(:workout_date)

    grouped = sessions.group_by(&:ph_id)

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
      # Skip the first date (2026-03-02 calibration) — use second date as baseline
      dates = d[:data].map { |p| p[:date] }.uniq.sort
      baseline_date = dates[1] || dates[0]
      baseline = d[:data].select { |p| p[:date] == baseline_date }.max_by { |p| p[:rm1] }
      latest   = d[:data].last
      next unless baseline && latest && baseline[:date] != latest[:date]
      change = ((latest[:rm1] - baseline[:rm1]) / baseline[:rm1] * 100).round(1)
      { name: d[:name], muscle_group: d[:muscle_group],
        baseline: baseline, latest: latest, pct_change: change }
    end.compact.sort_by { |p| -p[:pct_change] }
  end
end
