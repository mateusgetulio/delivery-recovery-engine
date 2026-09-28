require "test_helper"

module Webhooks
  class EnvelopeTest < ActiveSupport::TestCase
    test "parses a failure and reports missing payload fields" do
      envelope = Envelope.parse(failed_body)

      assert envelope.relevant?
      assert_equal [], envelope.payload_issues
      assert_equal Time.utc(2026, 9, 28, 10, 0, 0), envelope.occurred_at

      partial = Envelope.parse(JSON.generate(uuid: "u", event_type: "reward.delivery.failed", occurred_at: "2026-09-28T10:00:00Z", data: { reward_id: "rw_1" }))
      assert_equal [ "data.channel is missing", "data.reason is missing", "data.retryable is missing" ], partial.payload_issues
    end

    test "rejects malformed bodies with a reason" do
      assert_raises(Envelope::Malformed) { Envelope.parse("not json") }
      assert_raises(Envelope::Malformed) { Envelope.parse("[]") }
      assert_raises(Envelope::Malformed) { Envelope.parse(JSON.generate(event_type: "x", occurred_at: "2026-09-28T10:00:00Z")) }
      assert_raises(Envelope::Malformed) { Envelope.parse(JSON.generate(uuid: "u", event_type: "x", occurred_at: "yesterday")) }
    end

    test "an unknown event type is not relevant and needs no payload" do
      envelope = Envelope.parse(JSON.generate(uuid: "u", event_type: "reward.created", occurred_at: "2026-09-28T10:00:00Z"))

      refute envelope.relevant?
      assert_equal [], envelope.payload_issues
    end
  end
end
