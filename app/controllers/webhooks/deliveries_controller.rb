module Webhooks
  class DeliveriesController < ActionController::API
    def create
      raw_body = request.raw_post
      unless Signature.valid?(raw_body, request.headers[Signature::HEADER])
        IngestionCounter.count_rejected_signature!
        return render json: { status: "rejected", error: "invalid signature" }, status: :unauthorized
      end

      result = InboundEvents::Receive.call(raw_body: raw_body)
      render json: { status: result.status.to_s, error: result.error }.compact
    end
  end
end
