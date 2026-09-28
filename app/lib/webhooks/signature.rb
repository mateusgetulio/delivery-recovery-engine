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

    def self.secret
      ENV.fetch("WEBHOOK_SECRET") { Rails.application.credentials.webhook_secret || "development-only-secret" }
    end
  end
end
