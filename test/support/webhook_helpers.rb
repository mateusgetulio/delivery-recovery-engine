module WebhookHelpers
  SECRET = "test-secret".freeze

  def failed_body(uuid: SecureRandom.uuid, occurred_at: Time.utc(2026, 9, 28, 10, 0, 0), reward_id: "rw_1", reason: "mailbox_unavailable", retryable: true, channel: "email")
    JSON.generate(
      uuid: uuid,
      event_type: "reward.delivery.failed",
      occurred_at: occurred_at.iso8601,
      data: { reward_id: reward_id, channel: channel, reason: reason, retryable: retryable }
    )
  end

  def succeeded_body(uuid: SecureRandom.uuid, occurred_at: Time.utc(2026, 9, 28, 10, 5, 0), reward_id: "rw_1")
    JSON.generate(uuid: uuid, event_type: "reward.delivery.succeeded", occurred_at: occurred_at.iso8601, data: { reward_id: reward_id })
  end

  def signed_headers(body, secret: SECRET)
    { "CONTENT_TYPE" => "application/json", Webhooks::Signature::HEADER => Webhooks::Signature.sign(body, secret) }
  end

  def receive(body)
    InboundEvents::Receive.call(raw_body: body)
  end

  def process_all
    InboundEvent.pending.find_each { |event| InboundEvents::Process.call(event.id, reward_lookup: lookup) }
  end

  def lookup
    RewardLookup.new("rw_1" => { "channel" => "email", "destination" => "a***@example.com", "expires_at" => "2027-01-01T00:00:00Z" },
                     "rw_expired" => { "channel" => "email", "destination" => "e***@example.com", "expires_at" => "2020-01-01T00:00:00Z" })
  end
end
