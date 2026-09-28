require "test_helper"

module InboundEvents
  class EnqueuePendingTest < ActiveJob::TestCase
    test "enqueues only pending events older than the recovery window" do
      old = receive(failed_body).event
      fresh = receive(failed_body(reward_id: "rw_2")).event
      InboundEvent.where(id: old.id).update_all(received_at: 2.minutes.ago)
      clear_enqueued_jobs

      assert_enqueued_with(job: ProcessInboundEventJob, args: [ old.id ]) { assert_equal 1, EnqueuePending.call }
      assert_equal 1, enqueued_jobs.size
      refute_equal fresh.id, enqueued_jobs.sole[:args].first
    end
  end
end
