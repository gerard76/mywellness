class CreateWorkoutSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :workout_sessions do |t|
      t.references :machine, null: false, foreign_key: true
      t.date :workout_date, null: false
      t.float :rm1
      t.float :total_iso_weight
      t.timestamps
    end
    add_index :workout_sessions, [:machine_id, :workout_date]
  end
end
