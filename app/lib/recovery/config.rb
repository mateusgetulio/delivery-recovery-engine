module Recovery
  class Config
    Rule = Data.define(:reason, :same_destination, :prerequisite, :other_actions, :evidence)

    def self.load(path = Rails.root.join("config/recovery_rules.yml"))
      new(YAML.safe_load_file(path))
    end

    def initialize(data)
      @resend_cap = Integer(data.fetch("resend_cap"))
      @rules = data.fetch("reasons").to_h { |reason, rule| [ reason, build_rule(reason, rule) ] }.freeze
      @unknown_rule = build_rule(nil, data.fetch("unknown_reason"))
      @awaiting_recipient_reasons = data.fetch("awaiting_recipient_reasons").freeze
      unknown = @awaiting_recipient_reasons - @rules.keys
      raise ArgumentError, "awaiting_recipient_reasons lists unknown reasons: #{unknown.inspect}" if unknown.any?
    end

    attr_reader :resend_cap, :rules, :unknown_rule, :awaiting_recipient_reasons

    def known?(reason)
      rules.key?(reason)
    end

    def rule_for(reason)
      rules.fetch(reason) { unknown_rule }
    end

    def awaiting_recipient?(reason)
      awaiting_recipient_reasons.include?(reason)
    end

    private

    def build_rule(reason, rule)
      prerequisite = rule["prerequisite"]&.to_sym
      raise ArgumentError, "unknown prerequisite #{prerequisite.inspect} for #{reason}" if prerequisite && PREREQUISITES.exclude?(prerequisite)

      actions = rule.fetch("other_actions").map(&:to_sym)
      raise ArgumentError, "unknown action in #{reason}: #{actions.inspect}" unless (actions - ACTIONS).empty?
      raise ArgumentError, "same_destination must be true or false for #{reason}" unless [ true, false ].include?(rule.fetch("same_destination"))
      raise ArgumentError, "unknown evidence #{rule["evidence"].inspect} for #{reason}" unless EVIDENCE.include?(rule.fetch("evidence"))

      Rule.new(reason, rule.fetch("same_destination"), prerequisite, actions.freeze, rule.fetch("evidence"))
    end
  end
end
