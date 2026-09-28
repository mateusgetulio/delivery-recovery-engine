require "test_helper"

module Webhooks
  class SignatureTest < ActiveSupport::TestCase
    test "signs the raw body with HMAC-SHA256 hex and verifies in constant time" do
      body = '{"uuid":"1"}'
      signature = Signature.sign(body, "s")

      assert_equal OpenSSL::HMAC.hexdigest("SHA256", "s", body), signature
      assert Signature.valid?(body, signature, "s")
      refute Signature.valid?(body + " ", signature, "s")
      refute Signature.valid?(body, signature, "other")
      refute Signature.valid?(body, nil, "s")
      refute Signature.valid?(body, "", "s")
    end

    test "the fallback secret exists only in local environments" do
      ENV.delete("WEBHOOK_SECRET")
      assert_equal "development-only-secret", Signature.secret
      assert_raises(KeyError) { Signature.secret(ActiveSupport::EnvironmentInquirer.new("production")) }
    ensure
      ENV["WEBHOOK_SECRET"] = WebhookHelpers::SECRET
    end
  end
end
