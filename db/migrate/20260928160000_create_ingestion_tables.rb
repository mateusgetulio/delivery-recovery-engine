class CreateIngestionTables < ActiveRecord::Migration[8.1]
  def change
    create_table :inbound_events do |t|
      t.string :event_uuid, null: false
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.datetime :received_at, null: false
      t.text :raw_body, null: false
      t.json :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.string :ignored_reason
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.integer :duplicates_seen, null: false, default: 0
      t.timestamps
    end
    add_index :inbound_events, :event_uuid, unique: true
    add_index :inbound_events, :status

    create_table :rejected_requests do |t|
      t.text :raw_body, null: false
      t.string :error, null: false
      t.datetime :created_at, null: false
    end

    create_table :ingestion_counters do |t|
      t.integer :rejected_signatures, null: false, default: 0
      t.timestamps
    end
  end
end
