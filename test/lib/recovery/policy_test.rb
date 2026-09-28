require "test_helper"

module Recovery
  class PolicyTest < ActiveSupport::TestCase
    test "INV-1 the ambient clock does not influence the policy, only the injected one does" do
      expiring = facts(expires_at: now)

      travel_to(now - 1.year) { assert_equal :escalate, Policy.call(expiring, now: now).recommended_action }
      travel_to(now + 1.year) { assert_equal :resend_same_destination, Policy.call(expiring, now: now - 1).recommended_action }
      assert_equal Policy.call(facts, now: now), Policy.call(facts, now: now)
    end

    test "INV-1 the policy never calls the clock" do
      decision = forbidding_clock_reads { Policy.call(facts(expires_at: now), now: now - 1) }

      assert_equal :resend_same_destination, decision.recommended_action
      assert_raises(RuntimeError) { forbidding_clock_reads { Time.now } }
    end

    test "a retryable failure below the cap recommends the same destination with the documented alternatives" do
      decision = Policy.call(facts(reason: "domain_block"), now: now)

      assert_equal :resend_same_destination, decision.recommended_action
      assert_equal %i[resend_same_destination request_new_destination cancel], decision.allowed_actions
      assert_equal :retry_allowed, decision.reason_code
    end

    test "INV-2 a non-retryable failure never offers the same destination" do
      decision = Policy.call(facts(reason: "domain_block", retryable: false), now: now)

      assert_equal :request_new_destination, decision.recommended_action
      refute decision.allows?(:resend_same_destination)
      assert_equal :not_retryable, decision.reason_code
    end

    test "a reason whose documented route is a new destination never offers the same one" do
      decision = Policy.call(facts(reason: "invalid_email"), now: now)

      assert_equal %i[request_new_destination cancel], decision.allowed_actions
      assert_equal :new_destination, decision.reason_code
    end

    test "INV-3 the cap withholds the same destination at the cap and allows it one below" do
      below = Policy.call(facts(resend_count: 1), now: now)
      at = Policy.call(facts(resend_count: 2), now: now)

      assert below.allows?(:resend_same_destination)
      refute at.allows?(:resend_same_destination)
      assert_equal :resend_cap_reached, at.reason_code
      assert_equal :request_new_destination, at.recommended_action
    end

    test "INV-4 the relay prerequisite is organization scoped and gates the resend" do
      missing = Policy.call(facts(reason: "apple_private_relay", relay_domain_registered: false), now: now)
      satisfied = Policy.call(facts(reason: "apple_private_relay", relay_domain_registered: true), now: now)

      assert_equal :complete_prerequisite, missing.recommended_action
      refute missing.allows?(:resend_same_destination)
      assert_equal :prerequisite_missing, missing.reason_code
      assert_equal :relay_registration, missing.prerequisite
      assert_equal :resend_same_destination, satisfied.recommended_action
    end

    test "INV-4 the spam suppression prerequisite is case scoped and gates the resend" do
      missing = Policy.call(facts(reason: "spam_report", spam_suppression_removed: false), now: now)
      satisfied = Policy.call(facts(reason: "spam_report", spam_suppression_removed: true), now: now)

      assert_equal :complete_prerequisite, missing.recommended_action
      assert_equal :spam_suppression_removed, missing.prerequisite
      assert_equal :resend_same_destination, satisfied.recommended_action
    end

    test "INV-5 expiry is a boundary on the injected clock, not a stored flag" do
      expires_at = now
      before = Policy.call(facts(expires_at: expires_at), now: expires_at - 1)
      at = Policy.call(facts(expires_at: expires_at), now: expires_at)

      assert before.allows?(:resend_same_destination)
      assert_equal %i[escalate cancel], at.allowed_actions
      assert_equal :escalate, at.recommended_action
      assert_equal :expired, at.reason_code
    end

    test "INV-6 an unknown reason escalates and keeps the raw code" do
      decision = Policy.call(facts(reason: "carrier_pigeon_lost"), now: now)

      assert_equal [ :escalate ], decision.allowed_actions
      assert_equal :unknown_reason, decision.reason_code
      assert_includes decision.explanation, "carrier_pigeon_lost"
    end

    test "a settled case allows nothing, including a resolved one" do
      %w[resolved escalated cancelled].each do |status|
        decision = Policy.call(facts(status: status), now: now)

        assert_equal [], decision.allowed_actions
        assert_nil decision.recommended_action
        assert_equal :case_closed, decision.reason_code
      end
    end

    test "sms failures offer another delivery route" do
      decision = Policy.call(facts(channel: "sms", reason: "sms_delivery_failed"), now: now)

      assert_equal %i[resend_same_destination request_new_destination deliver_another_way cancel], decision.allowed_actions
    end

    test "INV-2 INV-3 INV-5 hold across generated facts and the result is deterministic" do
      generator = FactsGenerator.new
      config = Config.load

      200.times do
        facts = generator.facts(now)
        decision = Policy.call(facts, now: now, config: config)
        label = "seed #{generator.seed}: #{facts.inspect}"

        assert_equal decision, Policy.call(facts, now: now, config: config), label
        refute decision.allows?(:resend_same_destination), label if !facts.retryable
        refute decision.allows?(:resend_same_destination), label if facts.resend_count >= config.resend_cap
        refute decision.allows?(:resend_same_destination), label if facts.expired?(now)
        assert_equal [], decision.allowed_actions, label if facts.settled?
        refute decision.allows?(:resend_same_destination), label unless facts.prerequisite_satisfied?(config.rule_for(facts.reason).prerequisite)
        assert (decision.allowed_actions - %i[escalate cancel]).empty?, label unless config.known?(facts.reason)
        assert (decision.allowed_actions - Recovery::ACTIONS).empty?, label
        assert_equal decision.allowed_actions.first, decision.recommended_action, label unless decision.allowed_actions.empty?
      end
    end
  end
end
