require "test_helper"

module Demo
  class LocalStateTest < ActiveSupport::TestCase
    test "preloads local resend counts through audited transitions and is idempotent" do
      delivery_case = create_case(reward_id: "rw_capped")
      path = Rails.root.join("tmp/local_state_test.json")
      File.write(path, JSON.generate(delivery_cases: [ { reward_id: "rw_capped", resend_count: 2 }, { reward_id: "rw_missing", resend_count: 1 } ]))

      LocalState.apply(path)
      LocalState.apply(path)

      assert_equal 2, delivery_case.reload.resend_count
      assert_equal 2, delivery_case.transitions.where(actor_type: "operator").count
      assert_equal 0, DeliveryCase.where(reward_id: "rw_missing").count
    ensure
      File.delete(path) if File.exist?(path)
    end
  end
end
