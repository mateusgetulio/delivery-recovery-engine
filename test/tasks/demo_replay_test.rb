require "test_helper"
require "rake"

class DemoReplayTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { Rails.application.load_tasks unless Rake::Task.task_defined?("demo:replay") }

  teardown do
    [ Transition, DeliveryCase, InboundEvent, RejectedRequest, IngestionCounter, OrganizationSettings ].each(&:delete_all)
  end

  test "the fixture replays through the real webhook path and a second replay only counts duplicates" do
    replay

    first = snapshot
    assert_equal 24, first[:cases]
    assert_equal 0, first[:pending]
    assert_equal 0, first[:failed]
    assert_equal 5, first[:duplicates]
    assert_equal 1, first[:stale]
    assert_equal 2, DeliveryCase.find_by!(reward_id: "rw_capped").resend_count
    assert_equal "resolved", DeliveryCase.find_by!(reward_id: "rw_outoforder").status

    replay

    second = snapshot
    assert_equal first.except(:duplicates), second.except(:duplicates)
    assert_equal first[:duplicates] + fixture_size, second[:duplicates]
  end

  test "a tampered signature is counted and changes nothing else" do
    replay
    before = snapshot

    ENV["TAMPER"] = "1"
    replay
    ENV.delete("TAMPER")

    after = snapshot
    assert_equal 1, after[:rejected_signatures]
    assert_equal before.except(:duplicates, :rejected_signatures), after.except(:duplicates, :rejected_signatures)
  end

  private

  def fixture_size
    JSON.parse(File.read(Rails.root.join("fixtures/delivery_events.json"))).size
  end

  def replay
    Rake::Task["demo:replay"].reenable
    silence_stream($stdout) { Rake::Task["demo:replay"].invoke }
  end

  def snapshot
    {
      cases: DeliveryCase.count,
      transitions: Transition.count,
      pending: InboundEvent.pending.count,
      failed: InboundEvent.where(status: "failed").count,
      duplicates: InboundEvent.sum(:duplicates_seen),
      stale: InboundEvent.where(ignored_reason: "stale_event").count,
      rejected_signatures: IngestionCounter.current.rejected_signatures,
      statuses: DeliveryCase.order(:reward_id).pluck(:reward_id, :status, :resend_count)
    }
  end

  def silence_stream(stream)
    original = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(original)
  end
end
