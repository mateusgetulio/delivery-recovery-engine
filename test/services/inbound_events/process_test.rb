require "test_helper"

module InboundEvents
  class ProcessTest < ActiveSupport::TestCase
    test "a failure creates a case seeded from the reward lookup, one transition, and marks the event processed" do
      event = receive(failed_body(reason: "domain_block")).event

      result = Process.call(event.id, reward_lookup: lookup)

      assert_equal :applied, result.outcome
      delivery_case = DeliveryCase.sole
      assert_equal [ "rw_1", "domain_block", true, "awaiting_recipient", 0, "a***@example.com", Time.utc(2027, 1, 1) ],
        [ delivery_case.reward_id, delivery_case.reason, delivery_case.retryable, delivery_case.status, delivery_case.resend_count, delivery_case.destination, delivery_case.expires_at ]
      transition = Transition.sole
      assert_equal [ nil, "awaiting_recipient", "delivery_failed", "system", "inbound_event", event.event_uuid ],
        [ transition.from_status, transition.to_status, transition.action, transition.actor_type, transition.cause_type, transition.cause_id ]
      assert_equal "processed", event.reload.status
      assert_equal 1, event.attempts
    end

    test "INV-6 an unknown reason still opens a case and the policy escalates it" do
      event = receive(failed_body(reason: "carrier_pigeon_lost")).event

      Process.call(event.id, reward_lookup: lookup)

      delivery_case = DeliveryCase.sole
      assert_equal "carrier_pigeon_lost", delivery_case.reason
      assert_equal :escalate, Recovery::Policy.call(delivery_case.facts, now: now).recommended_action
      assert_equal "processed", event.reload.status
    end

    test "a newer failure replaces event facts and keeps local state" do
      first = receive(failed_body(reason: "domain_block", occurred_at: Time.utc(2026, 9, 28, 10, 0))).event
      Process.call(first.id, reward_lookup: lookup)
      delivery_case = DeliveryCase.sole
      delivery_case.commit_change!(action: "record_resend_attempt", actor_type: "operator", cause_type: "operator_action", cause_id: "op-1") { |c| c.resend_count = 1 }
      second = receive(failed_body(reason: "invalid_email", retryable: false, occurred_at: Time.utc(2026, 9, 28, 10, 30))).event

      Process.call(second.id, reward_lookup: lookup)

      delivery_case.reload
      assert_equal [ "invalid_email", false, "open", 1 ], [ delivery_case.reason, delivery_case.retryable, delivery_case.status, delivery_case.resend_count ]
      assert_equal 3, Transition.count
    end

    test "INV-10 a success resolves and an older failure arriving later is recorded as stale" do
      success = receive(succeeded_body(occurred_at: Time.utc(2026, 9, 28, 10, 5))).event
      Process.call(success.id, reward_lookup: lookup)
      stale = receive(failed_body(occurred_at: Time.utc(2026, 9, 28, 10, 0))).event

      result = Process.call(stale.id, reward_lookup: lookup)

      assert_equal :ignored, result.outcome
      assert_equal [ "resolved", nil ], [ DeliveryCase.sole.status, DeliveryCase.sole.reason ]
      assert_equal :case_closed, Recovery::Policy.call(DeliveryCase.sole.facts, now: now).reason_code
      assert_equal 1, Transition.count
      assert_equal [ "ignored", "stale_event" ], [ stale.reload.status, stale.ignored_reason ]
    end

    test "INV-10 a newer success after a failure resolves the case" do
      failure = receive(failed_body(occurred_at: Time.utc(2026, 9, 28, 10, 0))).event
      Process.call(failure.id, reward_lookup: lookup)
      success = receive(succeeded_body(occurred_at: Time.utc(2026, 9, 28, 10, 5))).event

      Process.call(success.id, reward_lookup: lookup)

      assert_equal "resolved", DeliveryCase.sole.status
      assert_equal %w[delivery_failed delivery_succeeded], Transition.order(:id).pluck(:action)
    end

    test "events for a closed case are recorded as ignored" do
      failure = receive(failed_body(occurred_at: Time.utc(2026, 9, 28, 10, 0))).event
      Process.call(failure.id, reward_lookup: lookup)
      DeliveryCase.sole.commit_change!(action: "cancel", actor_type: "operator", cause_type: "operator_action", cause_id: "op-9") { |c| c.status = "cancelled" }
      later = receive(succeeded_body(occurred_at: Time.utc(2026, 9, 28, 11, 0))).event

      Process.call(later.id, reward_lookup: lookup)

      assert_equal "cancelled", DeliveryCase.sole.status
      assert_equal [ "ignored", "case_closed" ], [ later.reload.status, later.ignored_reason ]
    end

    test "INV-9 re-running a processed event changes nothing" do
      event = receive(failed_body).event
      Process.call(event.id, reward_lookup: lookup)
      before = [ DeliveryCase.sole.attributes, Transition.count, event.reload.attributes ]

      result = Process.call(event.id, reward_lookup: lookup)

      assert_equal :already_processed, result.outcome
      assert_equal before, [ DeliveryCase.sole.attributes, Transition.count, event.reload.attributes ]
    end

    test "INV-9 a crash before commit leaves no case, no transition and the event pending" do
      event = receive(failed_body).event

      assert_raises(RuntimeError) do
        InboundEvent.transaction do
          Process.call(event.id, reward_lookup: lookup)
          raise "process died before commit"
        end
      end

      assert_equal 0, DeliveryCase.count
      assert_equal 0, Transition.count
      assert_equal [ "pending", 0 ], [ event.reload.status, event.attempts ]
    end

    test "INV-9 a transition that already exists for the event is honoured on retry" do
      event = receive(failed_body).event
      Process.call(event.id, reward_lookup: lookup)
      InboundEvent.where(id: event.id).update_all(status: "pending")

      result = Process.call(event.id, reward_lookup: lookup)

      assert_equal :already_processed, result.outcome
      assert_equal 1, Transition.count
      assert_equal "processed", event.reload.status
    end

    test "a processing error marks the event failed with the error and re-raises" do
      event = receive(failed_body).event
      broken = RewardLookup.new({})
      broken.define_singleton_method(:call) { |_| raise "lookup exploded" }

      assert_raises(RuntimeError) { Process.call(event.id, reward_lookup: broken) }

      assert_equal [ "failed", "RuntimeError: lookup exploded" ], [ event.reload.status, event.last_error ]
      assert_equal 0, DeliveryCase.count
    end

    test "a failed event can be processed again" do
      event = receive(failed_body).event
      InboundEvent.where(id: event.id).update_all(status: "failed", last_error: "earlier")

      Process.call(event.id, reward_lookup: lookup)

      assert_equal "processed", event.reload.status
      assert_equal 1, DeliveryCase.count
    end
  end
end
