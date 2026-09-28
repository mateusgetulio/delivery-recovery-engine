require "test_helper"

module Recovery
  class ConfigTest < ActiveSupport::TestCase
    test "loads the nine documented reasons, the cap and the unknown rule" do
      config = Config.load

      assert_equal 2, config.resend_cap
      assert_equal 9, config.rules.size
      assert_equal :relay_registration, config.rule_for("apple_private_relay").prerequisite
      assert_equal :spam_suppression_removed, config.rule_for("spam_report").prerequisite
      assert_equal "assumed", config.rule_for("smtp_delivery_failed").evidence
      assert_equal [ :escalate ], config.rule_for("something_new").other_actions
      refute config.known?("something_new")
    end

    test "rejects a rule with an unknown action, evidence, flag or waiting reason" do
      data = YAML.safe_load_file(Rails.root.join("config/recovery_rules.yml"))
      variants = [
        ->(d) { d["reasons"]["invalid_email"]["other_actions"] = [ "teleport" ] },
        ->(d) { d["reasons"]["invalid_email"]["evidence"] = "vibes" },
        ->(d) { d["reasons"]["invalid_email"]["same_destination"] = "yes" },
        ->(d) { d["awaiting_recipient_reasons"] = [ "nope" ] }
      ]

      variants.each do |mutate|
        broken = Marshal.load(Marshal.dump(data))
        mutate.call(broken)
        assert_raises(ArgumentError) { Config.new(broken) }
      end
    end
  end
end
