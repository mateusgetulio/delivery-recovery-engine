require "test_helper"

module Recovery
  class ActTest < ActiveSupport::TestCase
    test "recording a resend increments the count once and writes one operator transition" do
      delivery_case = create_case

      result = Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 0, now: now, cause_id: "op-1")

      delivery_case.reload
      assert_equal [ 1, "open", 1 ], [ delivery_case.resend_count, delivery_case.status, delivery_case.lock_version ]
      transition = Transition.where(actor_type: "operator").sole
      assert_equal [ "record_resend_attempt", "operator", "operator_action", "op-1", "open", "open" ],
        [ transition.action, transition.actor_type, transition.cause_type, transition.cause_id, transition.from_status, transition.to_status ]
      assert_equal [ delivery_case ], result.affected_cases
    end

    test "INV-3 the cap is enforced with a specific error and nothing is written" do
      delivery_case = create_case(resend_count: 2)

      assert_raises(ResendLimitReached) { Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 0, now: now) }

      assert_equal 2, delivery_case.reload.resend_count
      assert_equal 0, Transition.where(actor_type: "operator").count
    end

    test "INV-5 an expired reward refuses a resend and allows escalation" do
      delivery_case = create_case(expires_at: now - 1)

      assert_raises(RewardExpired) { Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 0, now: now) }
      Act.call(delivery_case.id, :escalate, expected_lock_version: 0, now: now)

      assert_equal "escalated", delivery_case.reload.status
    end

    test "INV-4 a resend is refused while the relay prerequisite is missing" do
      delivery_case = create_case(reason: "apple_private_relay", status: "awaiting_prerequisite")

      assert_raises(PrerequisiteMissing) { Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 0, now: now) }
      assert_equal 0, Transition.where(actor_type: "operator").count
    end

    test "INV-4 completing the relay prerequisite is organization scoped and reopens every waiting relay case" do
      first = create_case(reason: "apple_private_relay", status: "awaiting_prerequisite")
      second = create_case(reason: "apple_private_relay", status: "awaiting_prerequisite")
      spam = create_case(reason: "spam_report", status: "awaiting_prerequisite")

      result = Act.call(first.id, :complete_prerequisite, expected_lock_version: 0, now: now, cause_id: "op-2")

      assert OrganizationSettings.current.relay_domain_registered
      assert_equal [ "open", "open", "awaiting_prerequisite" ], [ first.reload.status, second.reload.status, spam.reload.status ]
      assert_equal [ first, second ], result.affected_cases
      assert_equal %w[mark_relay_domain_registered mark_relay_domain_registered], Transition.where(actor_type: "operator").order(:id).pluck(:action)
      assert_equal [ "op-2:#{first.id}", "op-2:#{second.id}" ], Transition.where(actor_type: "operator").order(:id).pluck(:cause_id)
      assert_equal :resend_same_destination, Policy.call(second.reload.facts, now: now).recommended_action
    end

    test "INV-4 completing the spam prerequisite is case scoped" do
      spam = create_case(reason: "spam_report", status: "awaiting_prerequisite")
      other = create_case(reason: "spam_report", status: "awaiting_prerequisite")

      Act.call(spam.id, :complete_prerequisite, expected_lock_version: 0, now: now)

      assert_equal [ true, "open" ], [ spam.reload.spam_suppression_removed, spam.status ]
      assert_equal [ false, "awaiting_prerequisite" ], [ other.reload.spam_suppression_removed, other.status ]
      assert_equal "mark_suppression_removed", Transition.where(actor_type: "operator").sole.action
    end

    test "recording a new destination resets the resend budget" do
      delivery_case = create_case(reason: "invalid_email", retryable: false, resend_count: 2)

      Act.call(delivery_case.id, :request_new_destination, expected_lock_version: 0, now: now, params: { destination: "n***@example.com" })

      delivery_case.reload
      assert_equal [ 0, "open", "n***@example.com" ], [ delivery_case.resend_count, delivery_case.status, delivery_case.destination ]
      assert_equal({ "destination" => "n***@example.com" }, Transition.where(actor_type: "operator").sole.metadata)
    end

    test "deliver another way resolves, escalate and cancel close, and closed cases refuse everything" do
      resolved = create_case(channel: "sms", reason: "sms_delivery_failed")
      Act.call(resolved.id, :deliver_another_way, expected_lock_version: 0, now: now)
      assert_equal "resolved", resolved.reload.status

      cancelled = create_case
      Act.call(cancelled.id, :cancel, expected_lock_version: 0, now: now)
      assert_equal "cancelled", cancelled.reload.status

      assert_raises(ActionNotAllowed) { Act.call(cancelled.id, :escalate, expected_lock_version: 1, now: now) }
      assert_raises(ActionNotAllowed) { Act.call(create_case.id, :deliver_another_way, expected_lock_version: 0, now: now) }
    end

    test "INV-12 a refused action writes no transition" do
      delivery_case = create_case(retryable: false)

      assert_raises(ActionNotAllowed) { Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 0, now: now) }

      assert_equal 0, Transition.where(actor_type: "operator").count
      assert_equal 0, delivery_case.reload.lock_version
    end

    test "a stale lock version is refused before anything is decided" do
      delivery_case = create_case

      assert_raises(StaleCaseVersion) { Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 7, now: now) }

      assert_equal 0, delivery_case.reload.resend_count
    end

    test "an unknown action is refused" do
      assert_raises(ActionNotAllowed) { Act.call(create_case.id, :teleport, expected_lock_version: 0, now: now) }
    end
  end
end
