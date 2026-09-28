module Recovery
  Decision = Data.define(:recommended_action, :allowed_actions, :reason_code, :explanation, :prerequisite, :rule) do
    def allows?(action)
      allowed_actions.include?(action)
    end
  end
end
