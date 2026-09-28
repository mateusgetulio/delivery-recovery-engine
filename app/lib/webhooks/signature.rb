module Webhooks
  module Signature
    HEADER = "X-Webhook-Signature".freeze

    def self.sign(raw_body, secret = self.secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
    end

    def self.valid?(raw_body, signature, secret = self.secret)
      return false if signature.blank?

      ActiveSupport::SecurityUtils.secure_compare(sign(raw_body, secret), signature.to_s)
    end

    def self.secret(env = Rails.env)
      ENV.fetch("WEBHOOK_SECRET") do
        Rails.application.credentials.webhook_secret ||
          (env.local? ? "development-only-secret" : raise(KeyError, "WEBHOOK_SECRET is not set"))
      end
    end
  end
end
