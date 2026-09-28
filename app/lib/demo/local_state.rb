module Demo
  class LocalState
    def self.apply(path)
      return unless File.exist?(path)

      JSON.parse(File.read(path)).fetch("delivery_cases", []).each do |row|
        delivery_case = DeliveryCase.find_by(reward_id: row.fetch("reward_id"))
        next if delivery_case.nil? || delivery_case.resend_count >= row.fetch("resend_count")

        (row.fetch("resend_count") - delivery_case.resend_count).times do |n|
          delivery_case.commit_change!(action: "record_resend_attempt", actor_type: "operator", cause_type: "operator_action", cause_id: "fixture:#{row['reward_id']}:#{n}", metadata: { source: "fixture local state" }) { |c| c.resend_count += 1 }
        end
      end
    end
  end
end
