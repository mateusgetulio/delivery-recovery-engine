module Recovery
  Facts = Data.define(:reward_id, :channel, :reason, :retryable, :expires_at, :status, :resend_count, :spam_suppression_removed, :relay_domain_registered, :latest_event_at) do
    def self.for(delivery_case, settings)
      new(
        reward_id: delivery_case.reward_id,
        channel: delivery_case.channel,
        reason: delivery_case.reason,
        retryable: delivery_case.retryable,
        expires_at: delivery_case.expires_at,
        status: delivery_case.status,
        resend_count: delivery_case.resend_count,
        spam_suppression_removed: delivery_case.spam_suppression_removed,
        relay_domain_registered: settings.relay_domain_registered,
        latest_event_at: delivery_case.latest_event_at
      )
    end

    def prerequisite_satisfied?(prerequisite)
      case prerequisite
      when nil then true
      when :relay_registration then relay_domain_registered
      when :spam_suppression_removed then spam_suppression_removed
      else raise ArgumentError, "unknown prerequisite #{prerequisite.inspect}"
      end
    end

    def expired?(now)
      !expires_at.nil? && expires_at <= now
    end

    def closed?
      CLOSED_STATUSES.include?(status)
    end

    def settled?
      SETTLED_STATUSES.include?(status)
    end
  end
end
