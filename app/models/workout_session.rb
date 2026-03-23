class WorkoutSession < ApplicationRecord
  belongs_to :machine

  validates :workout_date, presence: true
  validates :rm1, numericality: { greater_than: 0 }, allow_nil: true
end
