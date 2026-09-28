module Webhooks
  class Envelope
    class Malformed < StandardError; end

    REQUIRED = %w[uuid event_type occurred_at].freeze
    FAILURE_FIELDS = %w[reward_id channel reason retryable].freeze
    SUCCESS_FIELDS = %w[reward_id].freeze

    def self.parse(raw_body)
      data = JSON.parse(raw_body)
      raise Malformed, "body must be a JSON object" unless data.is_a?(Hash)

      missing = REQUIRED.reject { |key| data[key].present? }
      raise Malformed, "missing #{missing.join(', ')}" if missing.any?

      occurred_at = Time.iso8601(data["occurred_at"].to_s)
      new(data, occurred_at)
    rescue JSON::ParserError => e
      raise Malformed, "invalid JSON: #{e.message.truncate(80)}"
    rescue ArgumentError
      raise Malformed, "occurred_at must be an ISO 8601 timestamp"
    end

    def initialize(data, occurred_at)
      @data = data
      @occurred_at = occurred_at
    end

    attr_reader :occurred_at

    def uuid = data.fetch("uuid").to_s
    def event_type = data.fetch("event_type").to_s
    def payload = data.fetch("data", {})

    def relevant?
      Recovery::EVENT_TYPES.include?(event_type)
    end

    def payload_issues
      return [] unless relevant?

      required = event_type == "reward.delivery.failed" ? FAILURE_FIELDS : SUCCESS_FIELDS
      missing = required.reject { |key| payload.is_a?(Hash) && !payload[key].nil? && payload[key] != "" }
      missing.map { |key| "data.#{key} is missing" }
    end

    private

    attr_reader :data
  end
end
