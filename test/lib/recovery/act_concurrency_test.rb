require "test_helper"

module Recovery
  class ActConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    teardown do
      [ Transition, DeliveryCase, InboundEvent, RejectedRequest, IngestionCounter, OrganizationSettings ].each(&:delete_all)
    end

    test "INV-11 two operators recording the final resend cannot exceed the cap" do
      delivery_case = create_case(reward_id: "rw_race", resend_count: 1)
      barrier = Queue.new
      threads = Array.new(2) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            Act.call(delivery_case.id, :resend_same_destination, expected_lock_version: 0, now: now)
            :ok
          rescue StaleCaseVersion, ResendLimitReached => e
            e.class
          end
        end
      end
      2.times { barrier << true }
      outcomes = threads.map(&:value)

      assert_equal 1, outcomes.count(:ok), outcomes.inspect
      assert_equal 2, delivery_case.reload.resend_count
      assert_equal 1, Transition.where(actor_type: "operator").count
    end
  end
end
