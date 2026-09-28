module Recovery
  class Apply
    Effect = Data.define(:outcome, :attributes, :ignored_reason) do
      def applied? = outcome == :applied
    end

    def self.call(facts, event, config: Recovery.config)
      new(facts, event, config).call
    end

    def initialize(facts, event, config)
      @facts = facts
      @event = event
      @config = config
    end

    def call
      return Effect.new(:ignored, {}, :case_closed) if facts.closed?
      return Effect.new(:ignored, {}, :stale_event) if stale?

      if event.succeeded?
        Effect.new(:applied, { status: "resolved", latest_event_at: event.occurred_at }, nil)
      else
        Effect.new(:applied, failure_attributes, nil)
      end
    end

    private

    attr_reader :facts, :event, :config

    def stale?
      !facts.latest_event_at.nil? && event.occurred_at < facts.latest_event_at
    end

    def failure_attributes
      {
        status: status_after_failure,
        reason: event.reason,
        retryable: event.retryable,
        channel: event.channel,
        latest_event_at: event.occurred_at
      }
    end

    def status_after_failure
      rule = config.rule_for(event.reason)
      return "awaiting_prerequisite" unless facts.prerequisite_satisfied?(rule.prerequisite)
      return "awaiting_recipient" if config.awaiting_recipient?(event.reason)

      "open"
    end
  end
end
