class AddRewardIdToInboundEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :inbound_events, :reward_id, :string
    add_index :inbound_events, :reward_id
  end
end
