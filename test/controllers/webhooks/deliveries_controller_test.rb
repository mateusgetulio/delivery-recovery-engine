require "test_helper"

module Webhooks
  class DeliveriesControllerTest < ActionDispatch::IntegrationTest
    test "INV-7 an invalid signature stores nothing, enqueues nothing and is counted" do
      body = failed_body

      assert_no_enqueued_jobs do
        post delivery_webhook_path, params: body, headers: signed_headers(body, secret: "wrong")
      end

      assert_response :unauthorized
      assert_equal 0, InboundEvent.count
      assert_equal 0, RejectedRequest.count
      assert_equal 0, DeliveryCase.count
      assert_equal 1, IngestionCounter.current.rejected_signatures
    end

    test "INV-7 a missing signature is rejected the same way" do
      post delivery_webhook_path, params: failed_body, headers: { "CONTENT_TYPE" => "application/json" }

      assert_response :unauthorized
      assert_equal 0, InboundEvent.count
    end

    test "a valid signature stores the event, enqueues the job and answers accepted" do
      body = failed_body

      assert_enqueued_with(job: ProcessInboundEventJob) do
        post delivery_webhook_path, params: body, headers: signed_headers(body)
      end

      assert_response :success
      assert_equal({ "status" => "accepted" }, response.parsed_body)
      assert_equal "pending", InboundEvent.sole.status
    end

    test "INV-8 the same uuid twice answers duplicate and stores one row" do
      body = failed_body

      post delivery_webhook_path, params: body, headers: signed_headers(body)
      post delivery_webhook_path, params: body, headers: signed_headers(body)

      assert_response :success
      assert_equal({ "status" => "duplicate" }, response.parsed_body)
      assert_equal 1, InboundEvent.count
      assert_equal 1, InboundEvent.sole.duplicates_seen

      process_all

      assert_equal 1, DeliveryCase.count
      assert_equal 1, Transition.count
      assert_equal 0, DeliveryCase.sole.resend_count
    end

    test "a signed known event with a missing payload field is stored as ignored, keeping its uuid for dedupe" do
      body = JSON.generate(uuid: "u-1", event_type: "reward.delivery.failed", occurred_at: Time.utc(2026, 9, 28).iso8601, data: { reward_id: "rw_1" })

      assert_no_enqueued_jobs do
        post delivery_webhook_path, params: body, headers: signed_headers(body)
        post delivery_webhook_path, params: body, headers: signed_headers(body)
      end

      assert_equal "duplicate", response.parsed_body["status"]
      event = InboundEvent.sole
      assert_equal [ "ignored", "invalid_payload", "rw_1" ], [ event.status, event.ignored_reason, event.reward_id ]
      assert_match(/data.reason is missing/, event.last_error)
      assert_equal 0, RejectedRequest.count
    end

    test "a signed but malformed body answers 200 rejected and is kept visible" do
      body = '{"event_type": "reward.delivery.failed"}'

      post delivery_webhook_path, params: body, headers: signed_headers(body)

      assert_response :success
      assert_equal "rejected", response.parsed_body["status"]
      assert_match(/missing uuid/, response.parsed_body["error"])
      assert_equal 1, RejectedRequest.count
      assert_equal 0, InboundEvent.count
    end

    test "a signed irrelevant event answers ignored and is stored as ignored" do
      body = JSON.generate(uuid: SecureRandom.uuid, event_type: "reward.created", occurred_at: Time.utc(2026, 9, 28).iso8601)

      assert_no_enqueued_jobs do
        post delivery_webhook_path, params: body, headers: signed_headers(body)
      end

      assert_equal({ "status" => "ignored" }, response.parsed_body)
      assert_equal "ignored", InboundEvent.sole.status
      assert_equal "unsupported_event_type", InboundEvent.sole.ignored_reason
    end
  end
end
