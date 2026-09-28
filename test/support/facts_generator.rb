class FactsGenerator
  REASONS = (Recovery::Config.load.rules.keys + [ "carrier_pigeon_lost" ]).freeze

  def initialize(seed = Integer(ENV.fetch("RECOVERY_TEST_SEED", Random.new_seed)))
    @seed = seed
    @random = Random.new(seed)
  end

  attr_reader :seed

  def facts(now)
    Recovery::Facts.new(
      reward_id: "rw_#{random.rand(1000)}",
      channel: random.rand < 0.2 ? "sms" : "email",
      reason: REASONS.sample(random: random),
      retryable: random.rand < 0.7,
      expires_at: random.rand < 0.2 ? now - random.rand(1..3600) : now + random.rand(1..3600),
      status: Recovery::STATUSES.sample(random: random),
      resend_count: random.rand(0..3),
      spam_suppression_removed: random.rand < 0.5,
      relay_domain_registered: random.rand < 0.5,
      latest_event_at: nil
    )
  end

  private

  attr_reader :random
end
