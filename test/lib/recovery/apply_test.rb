require "test_helper"

module Recovery
  class ApplyTest < ActiveSupport::TestCase
    test "a failure on a fresh case opens it with the event facts and leaves local state alone" do
      effect = Apply.call(facts(latest_event_at: nil, resend_count: 1), failed_event(reason: "domain_block", retryable: true))

      assert effect.applied?
      assert_equal "awaiting_recipient", effect.attributes[:status]
      assert_equal "domain_block", effect.attributes[:reason]
      refute effect.attributes.key?(:resend_count)
      refute effect.attributes.key?(:spam_suppression_removed)
    end

    test "a failure with an unmet prerequisite waits for the prerequisite" do
      event = failed_event(reason: "apple_private_relay")
      expected = { reason: "apple_private_relay", retryable: true, channel: "email", latest_event_at: event.occurred_at }

      effect = Apply.call(facts(latest_event_at: nil, relay_domain_registered: false), event)
      assert_equal expected.merge(status: "awaiting_prerequisite"), effect.attributes

      effect = Apply.call(facts(latest_event_at: nil, relay_domain_registered: true), event)
      assert_equal expected.merge(status: "open"), effect.attributes
    end

    test "INV-10 a success resolves and a stale failure afterwards is ignored" do
      success_at = Time.utc(2026, 9, 28, 10, 5)
      resolved = Apply.call(facts(latest_event_at: nil), succeeded_event(occurred_at: success_at))
      assert_equal({ status: "resolved", latest_event_at: success_at }, resolved.attributes)

      stale = Apply.call(facts(status: "resolved", latest_event_at: success_at), failed_event(occurred_at: success_at - 60))
      refute stale.applied?
      assert_equal :stale_event, stale.ignored_reason
    end

    test "INV-10 a newer failure reopens a resolved case" do
      effect = Apply.call(facts(status: "resolved", latest_event_at: now - 60), failed_event(occurred_at: now))

      assert_equal({ status: "awaiting_recipient", reason: "mailbox_unavailable", retryable: true, channel: "email", latest_event_at: now }, effect.attributes)
    end

    test "INV-10 an equal timestamp is not stale" do
      effect = Apply.call(facts(latest_event_at: now), failed_event(occurred_at: now, reason: "invalid_email"))

      assert_equal({ status: "open", reason: "invalid_email", retryable: true, channel: "email", latest_event_at: now }, effect.attributes)
    end

    test "closed cases ignore every event" do
      %w[escalated cancelled].each do |status|
        effect = Apply.call(facts(status: status, latest_event_at: now - 60), succeeded_event(occurred_at: now))

        assert_equal :case_closed, effect.ignored_reason
      end
    end
  end
end
