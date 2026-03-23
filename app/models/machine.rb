class Machine < ApplicationRecord
  has_many :workout_sessions, dependent: :destroy

  validates :ph_id, presence: true, uniqueness: true

  MUSCLE_GROUPS = [
    "Arms",
    "Chest & Shoulders",
    "Back",
    "Core",
    "Legs",
    "Other"
  ].freeze

  def display_name
    name.present? ? name : "Unknown (#{ph_id.first(8)}...)"
  end

  # Returns [{date:, rm1:}, ...] averaged per day, sorted by date
  def daily_rm1
    workout_sessions
      .group(:workout_date)
      .average(:rm1)
      .sort_by { |date, _| date }
      .map { |date, avg| { date: date.to_s, rm1: avg.round(2) } }
  end

  # Latest TotalIsoWeight (average of most recent day)
  def latest_total_iso_weight
    latest = workout_sessions.order(workout_date: :desc).first
    return nil unless latest
    workout_sessions
      .where(workout_date: latest.workout_date)
      .average(:total_iso_weight)
      &.round(2)
  end
end
