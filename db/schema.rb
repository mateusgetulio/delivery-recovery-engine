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

ActiveRecord::Schema[8.1].define(version: 2026_09_28_170000) do
  create_table "delivery_cases", force: :cascade do |t|
    t.string "reward_id", null: false
    t.string "channel"
    t.string "reason"
    t.boolean "retryable", default: false, null: false
    t.string "destination"
    t.datetime "expires_at"
    t.string "status", default: "open", null: false
    t.integer "resend_count", default: 0, null: false
    t.boolean "spam_suppression_removed", default: false, null: false
    t.datetime "latest_event_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reward_id"], name: "index_delivery_cases_on_reward_id", unique: true
    t.index ["status"], name: "index_delivery_cases_on_status"
  end

  create_table "inbound_events", force: :cascade do |t|
    t.string "event_uuid", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.datetime "received_at", null: false
    t.text "raw_body", null: false
    t.json "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.string "ignored_reason"
    t.integer "attempts", default: 0, null: false
    t.text "last_error"
    t.integer "duplicates_seen", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reward_id"
    t.index ["event_uuid"], name: "index_inbound_events_on_event_uuid", unique: true
    t.index ["reward_id"], name: "index_inbound_events_on_reward_id"
    t.index ["status"], name: "index_inbound_events_on_status"
  end

  create_table "ingestion_counters", force: :cascade do |t|
    t.integer "rejected_signatures", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "organization_settings", force: :cascade do |t|
    t.boolean "relay_domain_registered", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rejected_requests", force: :cascade do |t|
    t.text "raw_body", null: false
    t.string "error", null: false
    t.datetime "created_at", null: false
  end

  create_table "transitions", force: :cascade do |t|
    t.integer "delivery_case_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.string "action", null: false
    t.string "actor_type", null: false
    t.string "cause_type", null: false
    t.string "cause_id", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["cause_type", "cause_id"], name: "index_transitions_on_cause_type_and_cause_id", unique: true
    t.index ["delivery_case_id"], name: "index_transitions_on_delivery_case_id"
  end

  add_foreign_key "transitions", "delivery_cases"
end
