require "test_helper"

class CasesControllerTest < ActionDispatch::IntegrationTest
  test "the queue shows ingestion counts and groups by recommendation" do
    create_case(reward_id: "rw_a")
    create_case(reward_id: "rw_b", reason: "invalid_email", retryable: false)
    create_case(reward_id: "rw_c", reason: "apple_private_relay", status: "awaiting_prerequisite")
    RejectedRequest.create!(raw_body: "{", error: "invalid JSON")

    get root_path

    assert_response :success
    assert_select ".count.warn strong", "1"
    assert_select ".pill", text: /Retry same destination 1/
    assert_select ".pill", text: /New destination required 1/
    assert_select ".pill", text: /Complete prerequisite 1/
    assert_select "table.cases tbody tr", 3
  end

  test "the queue filters settled cases under none and refuses a bad form gracefully" do
    create_case(reward_id: "rw_a")
    create_case(reward_id: "rw_done", status: "resolved")

    get root_path(recommendation: "none")
    assert_select "table.cases tbody tr", 1
    assert_select "td", "rw_done"

    post case_actions_path(DeliveryCase.find_by!(reward_id: "rw_a")), params: { action_name: "", lock_version: "abc" }
    assert_response :redirect
    follow_redirect!
    assert_select ".flash.alert"
  end

  test "the queue filters by recommendation" do
    create_case(reward_id: "rw_a")
    create_case(reward_id: "rw_b", reason: "invalid_email", retryable: false)

    get root_path(recommendation: "request_new_destination")

    assert_select "table.cases tbody tr", 1
    assert_select "td", "rw_b"
  end

  test "the detail page shows facts with owners, the explanation and only allowed actions" do
    delivery_case = create_case(reason: "apple_private_relay", status: "awaiting_prerequisite")
    delivery_case.transitions.create!(to_status: "awaiting_prerequisite", action: "delivery_failed", actor_type: "system", cause_type: "inbound_event", cause_id: "evt-1")

    get case_path(delivery_case)

    assert_response :success
    assert_select ".recommendation", "Complete prerequisite"
    assert_select ".explanation", /private relay/
    assert_select ".owner-event", minimum: 3
    assert_select ".owner-local", minimum: 1
    assert_select "button", "Mark relay domain registered"
    assert_select "button", { text: "Record resend attempt", count: 0 }
    assert_select "input[name=lock_version][value=?]", "0"
    assert_select ".timeline .entry", 2
  end

  test "recording an action redirects with a notice and applies it" do
    delivery_case = create_case

    post case_actions_path(delivery_case), params: { action_name: "resend_same_destination", lock_version: 0 }

    assert_redirected_to case_path(delivery_case)
    assert_equal 1, delivery_case.reload.resend_count
    follow_redirect!
    assert_select ".flash.notice", /Record resend attempt recorded/
  end

  test "a stale form is refused with an alert and applies nothing" do
    delivery_case = create_case

    post case_actions_path(delivery_case), params: { action_name: "resend_same_destination", lock_version: 3 }

    assert_redirected_to case_path(delivery_case)
    follow_redirect!
    assert_select ".flash.alert", /changed since it was shown/
    assert_equal 0, delivery_case.reload.resend_count
  end

  test "a refused action shows the domain explanation" do
    delivery_case = create_case(resend_count: 2)

    post case_actions_path(delivery_case), params: { action_name: "resend_same_destination", lock_version: 0 }
    follow_redirect!

    assert_select ".flash.alert", /resend cap of 2/
  end
end
