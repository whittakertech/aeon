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

ActiveRecord::Schema[7.1].define(version: 2025_06_01_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "whittaker_tech_aeon_allocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "schedulable_type", null: false
    t.string "schedulable_id", null: false
    t.integer "temporal_kind", null: false
    t.timestamptz "starts_at", null: false
    t.integer "duration_seconds"
    t.string "timezone"
    t.jsonb "rrule"
    t.timestamptz "valid_from", null: false
    t.timestamptz "valid_to"
    t.timestamptz "projected_until", null: false
    t.uuid "supersedes_allocation_id"
    t.string "occurrence_retention_policy"
    t.string "attachment_version_ref"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["schedulable_type", "schedulable_id"], name: "idx_aeon_allocations_active_per_schedulable", unique: true, where: "(valid_to IS NULL)"
    t.index ["schedulable_type", "schedulable_id"], name: "idx_aeon_allocations_on_schedulable"
  end

  create_table "whittaker_tech_aeon_occurrences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "allocation_id", null: false
    t.tstzrange "time_range", null: false
    t.timestamptz "starts_at", null: false
    t.timestamptz "ends_at", null: false
    t.integer "state", default: 0, null: false
    t.string "projection_fingerprint"
    t.timestamptz "projected_at"
    t.timestamptz "invalidated_at"
    t.uuid "invalidated_by_allocation_id"
    t.timestamptz "purged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["allocation_id", "starts_at"], name: "idx_aeon_occurrences_active", where: "((invalidated_at IS NULL) AND (purged_at IS NULL))"
    t.index ["allocation_id", "starts_at"], name: "idx_aeon_occurrences_unique_per_allocation", unique: true
    t.index ["time_range"], name: "idx_aeon_occurrences_on_time_range", using: :gist
  end

  create_table "whittaker_tech_aeon_overrides", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "occurrence_id", null: false
    t.tstzrange "replacement_time_range"
    t.boolean "canceled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["occurrence_id"], name: "idx_aeon_overrides_unique_per_occurrence", unique: true
  end

  add_foreign_key "whittaker_tech_aeon_allocations", "whittaker_tech_aeon_allocations", column: "supersedes_allocation_id"
  add_foreign_key "whittaker_tech_aeon_occurrences", "whittaker_tech_aeon_allocations", column: "allocation_id"
  add_foreign_key "whittaker_tech_aeon_occurrences", "whittaker_tech_aeon_allocations", column: "invalidated_by_allocation_id"
  add_foreign_key "whittaker_tech_aeon_overrides", "whittaker_tech_aeon_occurrences", column: "occurrence_id"
end
