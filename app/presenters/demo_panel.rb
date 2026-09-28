class DemoPanel
  RelayCase = Data.define(:delivery_case, :recommendation)

  def initialize(number, now: Time.current)
    @step = Demo::Tour.step(number)
    @now = now
  end

  attr_reader :step

  def number = step.number
  def total = Demo::Tour::STEPS.size
  def title = step.title
  def why = step.why
  def first? = number == 1
  def last? = number == total

  def what
    return step.what unless number == 4 && prepared_case

    if prepared_case.resend_count >= Recovery.config.resend_cap
      "The prototype's configured retry limit of #{Recovery.config.resend_cap} has been reached. The resend action is gone and the recommendation moved to a different route."
    else
      "This case has #{Recovery.config.resend_cap - prepared_case.resend_count} retry remaining under the prototype's configured retry limit of #{Recovery.config.resend_cap}."
    end
  end

  def instruction
    case step.primary_action
    when :simulate then nil
    when :complete_prerequisite then "Click Mark relay domain registered. It runs the real application action."
    when :resend_same_destination then prepared_case && prepared_case.resend_count < Recovery.config.resend_cap ? "Click Record resend attempt to record the final attempt." : nil
    end
  end

  def relay_cases
    return [] unless number == 3

    settings = OrganizationSettings.current
    DeliveryCase.where(reason: "apple_private_relay").order(:reward_id).map do |delivery_case|
      decision = Recovery::Policy.call(delivery_case.facts(settings), now: @now, config: Recovery.config)
      RelayCase.new(delivery_case, CasePresenter.recommendation_label(decision.recommended_action))
    end
  end

  private

  def prepared_case
    @prepared_case ||= DeliveryCase.find_by(reward_id: Demo::Tour::PREPARED_RESEND_REWARD)
  end
end
