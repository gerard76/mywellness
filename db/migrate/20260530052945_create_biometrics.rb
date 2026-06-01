class CreateBiometrics < ActiveRecord::Migration[7.2]
  def change
    create_table :biometrics do |t|
      t.string :name, null: false
      t.date :measured_on, null: false
      t.float :value

      t.timestamps
    end
    add_index :biometrics, [:name, :measured_on], unique: true
  end
end
