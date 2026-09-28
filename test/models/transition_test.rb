require "test_helper"

class TransitionTest < ActiveSupport::TestCase
  test "INV-12 transitions are append-only" do
    delivery_case = create_case
    transition = delivery_case.transitions.create!(to_status: "open", action: "failure_received", actor_type: "system", cause_type: "inbound_event", cause_id: "evt-9")

    assert_raises(ActiveRecord::ReadOnlyRecord) { transition.update!(action: "tampered") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { transition.destroy! }
    assert_equal "failure_received", transition.reload.action
  end
end
