module InboundEvents
  class Process
    Result = Data.define(:outcome, :delivery_case, :ignored_reason)

    def self.call(inbound_event_id, reward_lookup: RewardLookup.default, config: Recovery.config)
      new(inbound_event_id, reward_lookup, config).call
    end

    def initialize(inbound_event_id, reward_lookup, config)
      @inbound_event_id = inbound_event_id
      @reward_lookup = reward_lookup
      @config = config
    end

    def call
      InboundEvent.transaction do
        inbound = InboundEvent.lock.find(inbound_event_id)
        return Result.new(:already_processed, nil, nil) unless inbound.status == "pending" || inbound.status == "failed"
        return already_applied(inbound) if Transition.exists?(cause_type: "inbound_event", cause_id: inbound.event_uuid)

        inbound.increment!(:attempts)
        apply(inbound)
      end
    rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique
      raise
    rescue StandardError => e
      InboundEvent.where(id: inbound_event_id).update_all(status: "failed", last_error: "#{e.class}: #{e.message}".truncate(500))
      raise
    end

    private

    attr_reader :inbound_event_id, :reward_lookup, :config

    def apply(inbound)
      event = inbound.to_recovery_event
      delivery_case = DeliveryCase.lock.find_or_initialize_by(reward_id: event.reward_id)
      reward = reward_lookup.call(event.reward_id)
      seed_new_case(delivery_case, event, reward) if delivery_case.new_record?
      effect = Recovery::Apply.call(delivery_case.facts(OrganizationSettings.current), event, config: config)

      if effect.applied?
        delivery_case.commit_change!(action: action_for(event), actor_type: "system", cause_type: "inbound_event", cause_id: inbound.event_uuid, metadata: metadata_for(event)) do |c|
          c.assign_attributes(effect.attributes)
        end
        inbound.update!(status: "processed", ignored_reason: nil)
        Result.new(:applied, delivery_case, nil)
      else
        inbound.update!(status: "ignored", ignored_reason: effect.ignored_reason.to_s)
        Result.new(:ignored, delivery_case, effect.ignored_reason)
      end
    end

    def seed_new_case(delivery_case, event, reward)
      delivery_case.assign_attributes(
        channel: event.channel || reward&.channel,
        reason: event.reason,
        retryable: event.retryable || false,
        destination: reward&.destination,
        expires_at: reward&.expires_at
      )
    end

    def already_applied(inbound)
      inbound.update!(status: "processed", ignored_reason: "already_applied")
      Result.new(:already_processed, nil, nil)
    end

    def action_for(event)
      event.succeeded? ? "delivery_succeeded" : "delivery_failed"
    end

    def metadata_for(event)
      { event_type: event.event_type, reason: event.reason, retryable: event.retryable, occurred_at: event.occurred_at&.iso8601 }.compact
    end
  end
end
