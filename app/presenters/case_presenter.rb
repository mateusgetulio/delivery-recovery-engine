class CasePresenter
  ACTION_LABELS = {
    complete_prerequisite: "Mark prerequisite complete",
    resend_same_destination: "Record resend attempt",
    request_new_destination: "Record new destination",
    deliver_another_way: "Mark delivered another way",
    escalate: "Escalate",
    cancel: "Cancel case"
  }.freeze

  PREREQUISITE_LABELS = {
    relay_registration: "Mark relay domain registered",
    spam_suppression_removed: "Mark suppression removed"
  }.freeze

  RECOMMENDATION_LABELS = {
    complete_prerequisite: "Complete prerequisite",
    resend_same_destination: "Retry same destination",
    request_new_destination: "New destination required",
    deliver_another_way: "Deliver another way",
    escalate: "Escalate",
    cancel: "Cancel"
  }.freeze

  def initialize(delivery_case, decision)
    @delivery_case = delivery_case
    @decision = decision
  end

  attr_reader :delivery_case, :decision

  def recommendation_label
    decision.recommended_action ? RECOMMENDATION_LABELS.fetch(decision.recommended_action) : "None"
  end

  def action_label(action)
    return PREREQUISITE_LABELS.fetch(decision.prerequisite) if action == :complete_prerequisite && decision.prerequisite

    ACTION_LABELS.fetch(action)
  end

  def self.recommendation_label(action)
    action ? RECOMMENDATION_LABELS.fetch(action) : "None"
  end
end
