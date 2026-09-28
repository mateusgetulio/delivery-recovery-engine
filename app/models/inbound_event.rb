class InboundEvent < ApplicationRecord
  STATUSES = %w[pending processed ignored failed].freeze

  validates :event_uuid, :event_type, :occurred_at, :received_at, :raw_body, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }

  def processed? = status == "processed"

  def to_recovery_event
    Recovery::Event.new(
      uuid: event_uuid,
      event_type: event_type,
      occurred_at: occurred_at,
      reward_id: payload.fetch("reward_id"),
      channel: payload["channel"],
      reason: payload["reason"],
      retryable: payload["retryable"]
    )
  end
end
