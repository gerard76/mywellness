class AddUniqueIndexToWorkoutSessions < ActiveRecord::Migration[7.2]
  # One row per machine per day. The importer already upserts on this pair, but
  # the old non-unique index let a double import create duplicates.
  def change
    remove_index :workout_sessions, [:machine_id, :workout_date]
    add_index :workout_sessions, [:machine_id, :workout_date], unique: true
  end
end
