require "test_helper"

class DemoControllerTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  teardown { Demo::Reset.call }

  test "the landing page offers to start and starting resets to an empty queue with the first panel" do
    create_case(reward_id: "rw_leftover")

    get demo_path
    assert_response :success
    assert_select "button", "Start Guided Demo"
    assert_select "p.muted", /1 cases currently in the queue will be removed/

    post demo_start_path
    assert_redirected_to demo_step_path(1)
    follow_redirect!
    assert_redirected_to root_path
    follow_redirect!

    assert_equal 0, DeliveryCase.count
    assert_select "body.in-demo"
    assert_select ".demo-step", "Demo 1 of 6"
    assert_select ".demo-panel h2", "New failures arrive"
    assert_select ".demo-panel button", "Simulate incoming delivery events"
    assert_select ".demo-nav span.muted", "← Back"
    assert_select ".demo-nav a", "Next →"
    assert_select "button", "Exit demo"
  end

  test "the six steps walk through the real screens and actions in order" do
    post demo_start_path
    post demo_simulate_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".demo-confirm", "26 events accepted · 5 duplicates ignored"
    assert_select "table.cases tbody tr", 24
    prepared_case = DeliveryCase.find_by!(reward_id: "rw_007")
    assert_equal 1, prepared_case.resend_count
    assert_equal "fixture local state", prepared_case.transitions.where(actor_type: "operator").sole.metadata["source"]

    get demo_step_path(2)
    relay = DeliveryCase.find_by!(reward_id: "rw_006")
    assert_redirected_to case_path(relay)
    follow_redirect!
    assert_select ".demo-step", "Demo 2 of 6"
    assert_select ".recommendation", "Complete prerequisite"
    assert_select ".withheld", "Retry unavailable"
    assert_select ".demo-instruction", /Mark relay domain registered/
    assert_select "button.primary", "Mark relay domain registered"

    post case_actions_path(relay), params: { action_name: "complete_prerequisite", lock_version: relay.lock_version }
    follow_redirect!
    assert_select ".demo-step", "Demo 3 of 6"
    assert_select ".recommendation", "Retry same destination"
    assert_select ".withheld", count: 0
    assert_select ".demo-list li", 2
    assert_select ".demo-list li", /rw_015.*Retry same destination/m

    get demo_step_path(4)
    prepared = DeliveryCase.find_by!(reward_id: "rw_007")
    assert_redirected_to case_path(prepared)
    follow_redirect!
    assert_select ".demo-step", "Demo 4 of 6"
    assert_select ".demo-panel p", /1 retry remaining under the prototype's configured retry limit of 2/
    assert_select ".demo-instruction", /Record resend attempt/
    assert_select "button.primary", "Record resend attempt"

    post case_actions_path(prepared), params: { action_name: "resend_same_destination", lock_version: prepared.lock_version }
    follow_redirect!
    assert_select ".demo-step", "Demo 4 of 6"
    assert_select "button", { text: "Record resend attempt", count: 0 }
    assert_select ".explanation", /resend cap of 2/
    assert_select ".demo-panel p", /configured retry limit of 2 has been reached/
    assert_select ".demo-instruction", count: 0

    get demo_step_path(5)
    follow_redirect!
    assert_select ".demo-step", "Demo 5 of 6"
    assert_select ".recommendation", "Escalate"
    assert_select ".facts code", "carrier_pigeon_lost"

    get demo_step_path(6)
    follow_redirect!
    assert_select ".demo-step", "Demo 6 of 6"
    assert_select "h1 .status", "Resolved"
    assert_select ".timeline .entry", /stale event/i
    assert_select ".demo-nav a", "Finish Demo"

    get demo_finish_path
    assert_response :success
    assert_select "h1", "Demo complete"
    assert_select ".demo-summary li", 4
    assert_select ".demo-panel", count: 0

    delete demo_leave_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".demo-panel", count: 0
    assert_select "a", "Start Guided Demo"
  end

  test "restarting produces exactly the same state every time" do
    first = run_through
    second = run_through

    assert_equal first, second
  end

  test "a step that needs cases sends the presenter back to step one" do
    post demo_start_path

    get demo_step_path(2)

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash.alert", "Simulate incoming delivery events first."
    assert_select ".demo-step", "Demo 1 of 6"

    get demo_step_path(9)
    assert_redirected_to demo_path
  end

  test "the panel only appears inside the demo and the queue offers the demo when empty" do
    get root_path
    assert_select ".demo-panel", count: 0
    assert_select ".empty a", "Start the guided demo"

    get demo_step_path(1)
    assert_redirected_to demo_path
    post demo_simulate_path
    assert_redirected_to demo_path
    assert_equal 0, DeliveryCase.count

    post demo_start_path
    follow_redirect!
    follow_redirect!
    assert_select ".demo-panel"

    delete demo_leave_path
    get root_path
    assert_select ".demo-panel", count: 0
  end

  test "a refused action does not advance the tour, and Back from step three explains the prerequisite is already complete" do
    post demo_start_path
    post demo_simulate_path
    get demo_step_path(2)
    relay = DeliveryCase.find_by!(reward_id: "rw_006")

    post case_actions_path(relay), params: { action_name: "complete_prerequisite", lock_version: relay.lock_version + 5 }
    follow_redirect!
    assert_select ".flash.alert", /changed since it was shown/
    assert_select ".demo-step", "Demo 2 of 6"

    spam = DeliveryCase.find_by!(reward_id: "rw_005")
    post case_actions_path(spam), params: { action_name: "complete_prerequisite", lock_version: spam.lock_version }
    follow_redirect!
    assert_select ".demo-step", "Demo 2 of 6"

    post case_actions_path(relay), params: { action_name: "complete_prerequisite", lock_version: relay.lock_version }
    follow_redirect!
    assert_select ".demo-step", "Demo 3 of 6"

    get demo_step_path(2)
    follow_redirect!
    assert_select ".demo-step", "Demo 2 of 6"
    assert_select ".demo-instruction", /Already registered in this run/
    assert_select "button", { text: "Mark relay domain registered", count: 0 }
  end

  private

  def run_through
    post demo_restart_path
    post demo_simulate_path
    relay = DeliveryCase.find_by!(reward_id: "rw_006")
    post case_actions_path(relay), params: { action_name: "complete_prerequisite", lock_version: relay.lock_version }
    prepared = DeliveryCase.find_by!(reward_id: "rw_007")
    post case_actions_path(prepared), params: { action_name: "resend_same_destination", lock_version: prepared.lock_version }
    now = Time.utc(2026, 9, 28, 12, 0, 0)
    settings = OrganizationSettings.current
    {
      cases: DeliveryCase.order(:reward_id).map { |c| [ c.reward_id, c.status, c.resend_count, c.lock_version, Recovery::Policy.call(c.facts(settings), now: now, config: Recovery.config).recommended_action ] },
      transitions: Transition.order(:id).pluck(:action, :actor_type, :from_status, :to_status),
      events: InboundEvent.order(:id).pluck(:event_uuid, :status, :ignored_reason, :duplicates_seen),
      relay_registered: settings.relay_domain_registered
    }
  end
end
