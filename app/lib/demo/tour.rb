module Demo
  module Tour
    Step = Data.define(:number, :title, :what, :why, :reward_id, :primary_action, :advances_on)

    STEPS = [
      Step.new(
        number: 1,
        title: "New failures arrive",
        what: "A reward provider reports delivery failures. The system turns those events into cases an operator can work through.",
        why: "One queue, one row per failed reward, each with a recommendation. That is the product.",
        reward_id: nil,
        primary_action: :simulate,
        advances_on: nil
      ),
      Step.new(
        number: 2,
        title: "The system blocks an unsafe retry",
        what: "This delivery cannot safely be retried yet. The system tells the operator what is blocking it instead of simply showing an error.",
        why: "Operators get an actionable next step, not just a failure code.",
        reward_id: "rw_006",
        primary_action: :complete_prerequisite,
        advances_on: "complete_prerequisite"
      ),
      Step.new(
        number: 3,
        title: "One fix updates every affected case",
        what: "The prerequisite applies to the whole organization, so completing it once unlocks every affected case.",
        why: "The system understands the scope of the problem instead of forcing operators to fix identical cases one by one.",
        reward_id: "rw_006",
        primary_action: nil,
        advances_on: nil
      ),
      Step.new(
        number: 4,
        title: "The system knows when to stop retrying",
        what: "This case has one retry remaining under the prototype's configured retry limit.",
        why: "The UI prevents the operator from continuing an action after the prototype's configured retry limit has been reached.",
        reward_id: "rw_007",
        primary_action: :resend_same_destination,
        advances_on: nil
      ),
      Step.new(
        number: 5,
        title: "Unknown problems fail safe",
        what: "The system received a failure reason it does not recognize. Instead of guessing, it keeps the original information and recommends escalation.",
        why: "Unknown inputs fail safe rather than producing a potentially incorrect automated recommendation.",
        reward_id: "rw_unknown",
        primary_action: nil,
        advances_on: nil
      ),
      Step.new(
        number: 6,
        title: "Old information cannot undo newer truth",
        what: "A successful delivery was already known when an older failure arrived later. The event is kept in the history, but it does not reopen the case.",
        why: "Late or out-of-order events cannot silently undo newer state.",
        reward_id: "rw_outoforder",
        primary_action: nil,
        advances_on: nil
      )
    ].freeze

    FINISH = STEPS.size + 1
    PREPARED_RESEND_REWARD = "rw_007".freeze
    SESSION_KEY = :demo_step

    def self.step(number)
      STEPS.find { |step| step.number == number }
    end

    def self.current(session)
      number = session[SESSION_KEY]
      number.is_a?(Integer) && number.between?(1, FINISH) ? number : nil
    end

    def self.begin!(session)
      Reset.call
      session[SESSION_KEY] = 1
    end

    def self.go_to(session, number)
      session[SESSION_KEY] = number
    end

    def self.leave(session)
      session.delete(SESSION_KEY)
    end

    def self.simulate!
      Replay.call
    end

    def self.advance_after_action(session, action, delivery_case)
      number = current(session)
      return if number.nil?

      step = step(number)
      return unless step && step.advances_on == action.to_s && step.reward_id == delivery_case.reward_id

      session[SESSION_KEY] = number + 1
    end

    def self.destination_case(step)
      step.reward_id && DeliveryCase.find_by(reward_id: step.reward_id)
    end
  end
end
