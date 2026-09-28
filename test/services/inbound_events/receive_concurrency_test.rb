require "test_helper"

module InboundEvents
  class ReceiveConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    teardown do
      [ Transition, DeliveryCase, InboundEvent, RejectedRequest, IngestionCounter, OrganizationSettings ].each(&:delete_all)
    end

    test "INV-8 two threads receiving the same uuid produce one inbox row and one duplicate mark" do
      body = failed_body
      barrier = Queue.new
      threads = Array.new(2) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            Receive.call(raw_body: body).status
          end
        end
      end
      2.times { barrier << true }
      statuses = threads.map(&:value)

      assert_equal %i[accepted duplicate], statuses.sort
      assert_equal 1, InboundEvent.count
      assert_equal 1, InboundEvent.sole.duplicates_seen

      process_all

      assert_equal [ 1, 1, 0 ], [ DeliveryCase.count, Transition.count, DeliveryCase.sole.resend_count ]
    end
  end
end
