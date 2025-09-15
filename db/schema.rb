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

ActiveRecord::Schema[8.0].define(version: 2025_09_07_123000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "permitted_routes", force: :cascade do |t|
    t.string "carrier", null: false
    t.string "origin_iata", null: false
    t.string "destination_iata", null: false
    t.boolean "direct", default: true, null: false
    t.text "transfer_iata_codes", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier", "origin_iata", "destination_iata"], name: "idx_permitted_routes_key", unique: true
  end

  create_table "segments", force: :cascade do |t|
    t.string "airline", null: false
    t.string "segment_number", null: false
    t.string "origin_iata", limit: 3, null: false
    t.string "destination_iata", limit: 3, null: false
    t.datetime "std"
    t.datetime "sta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["airline", "origin_iata", "destination_iata", "std"], name: "idx_segments_route_lookup"
  end
end
