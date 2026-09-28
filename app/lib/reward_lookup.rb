class RewardLookup
  Reward = Data.define(:reward_id, :channel, :destination, :expires_at)

  def self.default
    from_file(Rails.root.join("fixtures/rewards.json"))
  end

  def self.from_file(path)
    return new({}) unless File.exist?(path)

    new(JSON.parse(File.read(path)).to_h { |row| [ row.fetch("reward_id"), row ] })
  end

  def initialize(rows)
    @rows = rows
  end

  def call(reward_id)
    row = rows[reward_id]
    return nil if row.nil?

    Reward.new(
      reward_id: reward_id,
      channel: row["channel"],
      destination: row["destination"],
      expires_at: row["expires_at"] && Time.iso8601(row["expires_at"])
    )
  end

  private

  attr_reader :rows
end
