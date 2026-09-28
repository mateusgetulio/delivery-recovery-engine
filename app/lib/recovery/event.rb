module Recovery
  Event = Data.define(:uuid, :event_type, :occurred_at, :reward_id, :channel, :reason, :retryable) do
    def failed?
      event_type == "reward.delivery.failed"
    end

    def succeeded?
      event_type == "reward.delivery.succeeded"
    end
  end
end
