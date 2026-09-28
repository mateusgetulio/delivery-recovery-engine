class Transition < ApplicationRecord
  ACTOR_TYPES = %w[system operator].freeze
  CAUSE_TYPES = %w[inbound_event operator_action].freeze

  belongs_to :delivery_case

  validates :action, presence: true
  validates :actor_type, inclusion: { in: ACTOR_TYPES }
  validates :from_status, inclusion: { in: Recovery::STATUSES }, allow_nil: true
  validates :cause_type, inclusion: { in: CAUSE_TYPES }
  validates :to_status, inclusion: { in: Recovery::STATUSES }

  def readonly?
    persisted?
  end
end
