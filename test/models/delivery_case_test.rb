require "test_helper"

class DeliveryCaseTest < ActiveSupport::TestCase
  test "INV-12 a business change outside commit_change! is refused" do
    delivery_case = create_case

    assert_raises(Recovery::Error) { delivery_case.update!(status: "resolved") }
    assert_raises(Recovery::Error) { delivery_case.update!(resend_count: 1) }
    assert_equal "open", delivery_case.reload.status
    assert_equal 1, delivery_case.transitions.count
  end

  test "INV-12 a case cannot be created outside commit_change!" do
    assert_raises(Recovery::Error) { DeliveryCase.create!(reward_id: "rw_new", status: "escalated", resend_count: 9) }

    assert_equal 0, DeliveryCase.count
    assert_equal 0, Transition.count
  end

  test "INV-12 creating through commit_change! records the birth transition" do
    delivery_case = DeliveryCase.new(reward_id: "rw_born", reason: "invalid_email")

    delivery_case.commit_change!(action: "delivery_failed", actor_type: "system", cause_type: "inbound_event", cause_id: "evt-b") { |c| c.status = "open" }

    assert delivery_case.persisted?
    assert_equal [ nil, "open" ], [ Transition.sole.from_status, Transition.sole.to_status ]
  end

  test "INV-12 commit_change! writes the change and exactly one transition together" do
    delivery_case = create_case

    delivery_case.commit_change!(action: "record_resend_attempt", actor_type: "operator", cause_type: "operator_action", cause_id: "op-1") do |c|
      c.resend_count += 1
    end

    assert_equal 1, delivery_case.reload.resend_count
    transition = delivery_case.transitions.order(:id).last
    assert_equal 2, delivery_case.transitions.count
    assert_equal [ "open", "open", "record_resend_attempt", "operator", "operator_action", "op-1" ],
      [ transition.from_status, transition.to_status, transition.action, transition.actor_type, transition.cause_type, transition.cause_id ]
  end

  test "INV-12 a failure inside commit_change! leaves neither the change nor a transition" do
    delivery_case = create_case

    assert_raises(ActiveRecord::RecordInvalid) do
      delivery_case.commit_change!(action: "escalate", actor_type: "operator", cause_type: "operator_action", cause_id: "op-2") do |c|
        c.status = "not_a_status"
      end
    end

    assert_equal "open", delivery_case.reload.status
    assert_equal 1, Transition.count
  end

  test "INV-12 the same cause cannot produce two transitions" do
    delivery_case = create_case
    change = -> { delivery_case.commit_change!(action: "escalate", actor_type: "system", cause_type: "inbound_event", cause_id: "evt-1") { |c| c.status = "escalated" } }
    change.call

    assert_raises(ActiveRecord::RecordNotUnique) { change.call }
    assert_equal 2, Transition.count
  end

  test "non-business attributes still save normally" do
    delivery_case = create_case

    delivery_case.update!(destination: "a***@example.com")

    assert_equal "a***@example.com", delivery_case.reload.destination
  end

  test "reward ids are unique" do
    delivery_case = create_case

    assert_raises(ActiveRecord::RecordNotUnique) { create_case(reward_id: delivery_case.reward_id) }
  end
end
