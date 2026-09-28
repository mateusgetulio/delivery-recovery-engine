module InboundEvents
  class Receive
    Result = Data.define(:status, :event, :error)

    def self.call(raw_body:, received_at: Time.current)
      new(raw_body, received_at).call
    end

    def initialize(raw_body, received_at)
      @raw_body = raw_body
      @received_at = received_at
    end

    def call
      envelope = Webhooks::Envelope.parse(raw_body)
      issues = envelope.payload_issues
      ignored_reason = ignored_reason_for(envelope, issues)
      event = InboundEvent.create!(
        event_uuid: envelope.uuid,
        event_type: envelope.event_type,
        occurred_at: envelope.occurred_at,
        received_at: received_at,
        raw_body: raw_body,
        payload: envelope.payload,
        reward_id: envelope.payload.is_a?(Hash) ? envelope.payload["reward_id"] : nil,
        status: ignored_reason ? "ignored" : "pending",
        ignored_reason: ignored_reason,
        last_error: issues.presence&.join("; ")
      )
      ProcessInboundEventJob.perform_later(event.id) unless ignored_reason
      Result.new(ignored_reason ? :ignored : :accepted, event, issues.presence&.join("; "))
    rescue ActiveRecord::RecordNotUnique
      existing = InboundEvent.find_by!(event_uuid: envelope.uuid)
      InboundEvent.where(id: existing.id).update_all("duplicates_seen = duplicates_seen + 1")
      Result.new(:duplicate, existing, nil)
    rescue Webhooks::Envelope::Malformed => e
      reject(e.message)
    end

    private

    attr_reader :raw_body, :received_at

    def ignored_reason_for(envelope, issues)
      return "unsupported_event_type" unless envelope.relevant?
      return "invalid_payload" if issues.any?

      nil
    end

    def reject(error)
      RejectedRequest.create!(raw_body: raw_body, error: error)
      Result.new(:rejected, nil, error)
    end
  end
end
