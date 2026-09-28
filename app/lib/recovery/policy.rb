module Recovery
  class Policy
    PRIORITY = ACTIONS

    EXPLANATIONS = {
      case_closed: "This case is %{status}. No further recovery actions apply.",
      expired: "The reward expired at %{expires_at}. Only support escalation or cancellation remain.",
      unknown_reason: "The failure reason %{reason} is not in the rules table. Escalate so a person can decide.",
      prerequisite_missing: "%{prerequisite_text} Same-destination resend is withheld until that is marked complete.",
      resend_cap_reached: "The resend cap of %{cap} for this case has been reached. Choose a different route.",
      not_retryable: "The provider marked this failure as not retryable to the same destination.",
      retry_allowed: "Same-destination resend is allowed for %{reason} (%{resends} of %{cap} resends used).",
      new_destination: "Same-destination resend is not offered for %{reason}. A different destination is the documented route."
    }.freeze

    PREREQUISITE_TEXT = {
      relay_registration: "This destination is a private relay address and the sending domain has not been registered with the relay provider.",
      spam_suppression_removed: "The recipient reported a previous message as spam and the suppression has not been marked removed."
    }.freeze

    def self.call(facts, now:, config: Recovery.config)
      new(facts, now, config).call
    end

    def initialize(facts, now, config)
      @facts = facts
      @now = now
      @config = config
    end

    def call
      rule = config.rule_for(facts.reason)
      allowed, reason_code = allowed_actions(rule)
      Decision.new(
        recommended_action: PRIORITY.find { |action| allowed.include?(action) },
        allowed_actions: allowed.freeze,
        reason_code: reason_code,
        explanation: explanation(reason_code, rule),
        prerequisite: rule.prerequisite,
        rule: rule
      )
    end

    private

    attr_reader :facts, :now, :config

    def allowed_actions(rule)
      return [ [], :case_closed ] if facts.settled?
      return [ %i[escalate cancel], :expired ] if facts.expired?(now)

      allowed = rule.other_actions.dup
      reason_code = config.known?(facts.reason) ? nil : :unknown_reason
      prerequisite_missing = !facts.prerequisite_satisfied?(rule.prerequisite)

      if rule.same_destination && facts.retryable && facts.resend_count < config.resend_cap && !prerequisite_missing
        allowed.unshift(:resend_same_destination)
        reason_code ||= :retry_allowed
      elsif prerequisite_missing
        allowed.unshift(:complete_prerequisite)
        reason_code ||= :prerequisite_missing
      elsif rule.same_destination && !facts.retryable
        reason_code ||= :not_retryable
      elsif rule.same_destination && facts.resend_count >= config.resend_cap
        reason_code ||= :resend_cap_reached
      else
        reason_code ||= :new_destination
      end

      [ PRIORITY & allowed, reason_code ]
    end

    def explanation(reason_code, rule)
      format(
        EXPLANATIONS.fetch(reason_code),
        status: facts.status,
        expires_at: facts.expires_at&.utc&.iso8601,
        reason: facts.reason,
        prerequisite_text: PREREQUISITE_TEXT[rule.prerequisite],
        cap: config.resend_cap,
        resends: facts.resend_count
      )
    end
  end
end
