require "test_helper"

class ProcessInboundEventJobTest < ActiveJob::TestCase
  test "processes the event through the service" do
    event = receive(failed_body).event

    perform_enqueued_jobs { ProcessInboundEventJob.perform_later(event.id) }

    assert_equal "processed", event.reload.status
    assert_equal 1, DeliveryCase.count
  end
end
