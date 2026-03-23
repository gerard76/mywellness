class CreateMachines < ActiveRecord::Migration[7.1]
  def change
    create_table :machines do |t|
      t.string :ph_id, null: false
      t.string :name
      t.string :muscle_group
      t.timestamps
    end
    add_index :machines, :ph_id, unique: true
  end
end
