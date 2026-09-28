module Recovery
  class Act
    ACTION_NAMES = {
      complete_prerequisite: "complete_prerequisite",
      resend_same_destination: "record_resend_attempt",
      request_new_destination: "record_new_destination",
      deliver_another_way: "mark_delivered_another_way",
      escalate: "escalate",
      cancel: "cancel"
    }.freeze

    Result = Data.define(:delivery_case, :decision, :affected_cases)

    def self.call(delivery_case_id, action, expected_lock_version:, now:, params: {}, cause_id: SecureRandom.uuid, config: Recovery.config)
      new(delivery_case_id, action.to_sym, expected_lock_version, now, params, cause_id, config).call
    end

    def initialize(delivery_case_id, action, expected_lock_version, now, params, cause_id, config)
      @delivery_case_id = delivery_case_id
      @action = action
      @expected_lock_version = expected_lock_version
      @now = now
      @params = params
      @cause_id = cause_id
      @config = config
    end

    def call
      raise ActionNotAllowed, "unknown action #{action}" unless ACTIONS.include?(action)

      DeliveryCase.transaction do
        delivery_case = DeliveryCase.lock.find(delivery_case_id)
        raise StaleCaseVersion, "case changed since it was shown" unless delivery_case.lock_version == expected_lock_version

        settings = OrganizationSettings.current(lock: true)
        decision = Policy.call(delivery_case.facts(settings), now: now, config: config)
        refuse(decision) unless decision.allows?(action)

        affected = perform(delivery_case, decision, settings)
        Result.new(delivery_case, decision, affected)
      end
    rescue ActiveRecord::StaleObjectError
      raise StaleCaseVersion, "case changed while the action was applied"
    end

    private

    attr_reader :delivery_case_id, :action, :expected_lock_version, :now, :params, :cause_id, :config

    def refuse(decision)
      message = decision.explanation
      case decision.reason_code
      when :resend_cap_reached then raise ResendLimitReached, message if action == :resend_same_destination
      when :expired then raise RewardExpired, message
      when :prerequisite_missing then raise PrerequisiteMissing, message if action == :resend_same_destination
      end
      raise ActionNotAllowed, "#{ACTION_NAMES.fetch(action)} is not allowed: #{message}"
    end

    def perform(delivery_case, decision, settings)
      case action
      when :complete_prerequisite then complete_prerequisite(delivery_case, decision.prerequisite, settings)
      when :resend_same_destination then change(delivery_case) { |c| c.resend_count += 1 }
      when :request_new_destination then change(delivery_case) { |c| c.status = "open"; c.resend_count = 0; c.destination = params[:destination].presence || c.destination }
      when :deliver_another_way then change(delivery_case) { |c| c.status = "resolved" }
      when :escalate then change(delivery_case) { |c| c.status = "escalated" }
      when :cancel then change(delivery_case) { |c| c.status = "cancelled" }
      end
    end

    def complete_prerequisite(delivery_case, prerequisite, settings)
      case prerequisite
      when :spam_suppression_removed
        change(delivery_case, name: "mark_suppression_removed") { |c| c.spam_suppression_removed = true; c.status = "open" }
      when :relay_registration
        settings.update!(relay_domain_registered: true)
        waiting = DeliveryCase.lock.where(status: "awaiting_prerequisite", reason: "apple_private_relay").order(:id).to_a
        waiting.map do |waiting_case|
          waiting_case.commit_change!(action: "mark_relay_domain_registered", actor_type: "operator", cause_type: "operator_action", cause_id: "#{cause_id}:#{waiting_case.id}") { |c| c.status = "open" }
          waiting_case
        end
      else
        raise ActionNotAllowed, "no prerequisite to complete"
      end
    end

    def change(delivery_case, name: ACTION_NAMES.fetch(action), &block)
      delivery_case.commit_change!(action: name, actor_type: "operator", cause_type: "operator_action", cause_id: cause_id, metadata: params.to_h.slice(:destination).compact, &block)
      [ delivery_case ]
    end
  end
end
