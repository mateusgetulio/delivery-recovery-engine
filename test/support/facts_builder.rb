module FactsBuilder
  def facts(**overrides)
    Recovery::Facts.new(**{
      reward_id: "rw_1",
      channel: "email",
      reason: "mailbox_unavailable",
      retryable: true,
      expires_at: Time.utc(2027, 1, 1),
      status: "open",
      resend_count: 0,
      spam_suppression_removed: false,
      relay_domain_registered: false,
      latest_event_at: nil
    }.merge(overrides))
  end

  def failed_event(**overrides)
    Recovery::Event.new(**{
      uuid: SecureRandom.uuid,
      event_type: "reward.delivery.failed",
      occurred_at: Time.utc(2026, 9, 28, 10, 0, 0),
      reward_id: "rw_1",
      channel: "email",
      reason: "mailbox_unavailable",
      retryable: true
    }.merge(overrides))
  end

  def succeeded_event(**overrides)
    failed_event(event_type: "reward.delivery.succeeded", reason: nil, retryable: nil, **overrides)
  end

  def now
    Time.utc(2026, 9, 28, 12, 0, 0)
  end
end
