class CreateRecoveryTables < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_settings do |t|
      t.boolean :relay_domain_registered, null: false, default: false
      t.timestamps
    end

    create_table :delivery_cases do |t|
      t.string :reward_id, null: false
      t.string :channel
      t.string :reason
      t.boolean :retryable, null: false, default: false
      t.string :destination
      t.datetime :expires_at
      t.string :status, null: false, default: "open"
      t.integer :resend_count, null: false, default: 0
      t.boolean :spam_suppression_removed, null: false, default: false
      t.datetime :latest_event_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :delivery_cases, :reward_id, unique: true
    add_index :delivery_cases, :status

    create_table :transitions do |t|
      t.references :delivery_case, null: false, foreign_key: true
      t.string :from_status
      t.string :to_status, null: false
      t.string :action, null: false
      t.string :actor_type, null: false
      t.string :cause_type, null: false
      t.string :cause_id, null: false
      t.json :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :transitions, [ :cause_type, :cause_id ], unique: true
  end
end
