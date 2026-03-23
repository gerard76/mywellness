# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2024_01_01_000003) do
  create_table "machines", force: :cascade do |t|
    t.string "ph_id", null: false
    t.string "name"
    t.string "muscle_group"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ph_id"], name: "index_machines_on_ph_id", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "workout_sessions", force: :cascade do |t|
    t.integer "machine_id", null: false
    t.date "workout_date", null: false
    t.float "rm1"
    t.float "total_iso_weight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["machine_id", "workout_date"], name: "index_workout_sessions_on_machine_id_and_workout_date"
    t.index ["machine_id"], name: "index_workout_sessions_on_machine_id"
  end

  add_foreign_key "workout_sessions", "machines"
end
