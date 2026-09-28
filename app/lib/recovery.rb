module Recovery
  ACTIONS = %i[complete_prerequisite resend_same_destination request_new_destination deliver_another_way escalate cancel].freeze
  PREREQUISITES = %i[relay_registration spam_suppression_removed].freeze
  STATUSES = %w[open awaiting_prerequisite awaiting_recipient resolved escalated cancelled].freeze
  CLOSED_STATUSES = %w[escalated cancelled].freeze
  SETTLED_STATUSES = %w[resolved escalated cancelled].freeze
  EVIDENCE = %w[documented assumed prototype].freeze
  EVENT_TYPES = %w[reward.delivery.failed reward.delivery.succeeded].freeze

  class Error < StandardError; end
  class ActionNotAllowed < Error; end
  class ResendLimitReached < ActionNotAllowed; end
  class RewardExpired < ActionNotAllowed; end
  class PrerequisiteMissing < ActionNotAllowed; end
  class StaleCaseVersion < Error; end

  def self.config
    @config ||= Config.load
  end
end
