class DeliveryCase < ApplicationRecord
  GUARDED_ATTRIBUTES = %w[status resend_count spam_suppression_removed reason retryable channel latest_event_at].freeze

  has_many :transitions, dependent: :restrict_with_exception

  validates :reward_id, presence: true
  validates :status, inclusion: { in: Recovery::STATUSES }
  validates :resend_count, numericality: { greater_than_or_equal_to: 0 }

  before_save :forbid_unaudited_business_change

  def commit_change!(action:, actor_type:, cause_type:, cause_id:, metadata: {})
    transaction do
      from_status = status_was_before_change
      yield self
      @audited_change = true
      save!
      transitions.create!(
        from_status: from_status,
        to_status: status,
        action: action,
        actor_type: actor_type,
        cause_type: cause_type,
        cause_id: cause_id,
        metadata: metadata
      )
    end
  ensure
    @audited_change = false
  end

  def facts(settings = OrganizationSettings.current)
    Recovery::Facts.for(self, settings)
  end

  private

  def status_was_before_change
    persisted? ? status_in_database : nil
  end

  def forbid_unaudited_business_change
    return if @audited_change
    raise Recovery::Error, "case created outside commit_change!" if new_record?

    changed_guarded = changed & GUARDED_ATTRIBUTES
    raise Recovery::Error, "business change to #{changed_guarded.join(', ')} outside commit_change!" if changed_guarded.any?
  end
end
