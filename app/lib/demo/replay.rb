module Demo
  class Replay
    Result = Data.define(:tally) do
      def accepted = tally.fetch("accepted", 0)
      def duplicates = tally.fetch("duplicate", 0)
      def rejected = tally.sum { |status, count| status.start_with?("rejected") ? count : 0 }
    end

    FIXTURE = "fixtures/delivery_events.json".freeze
    LOCAL_STATE = "fixtures/local_state.json".freeze

    def self.call(tamper: false)
      new(tamper).call
    end

    def initialize(tamper)
      @tamper = tamper
    end

    def call
      require "rack/test"
      session = Rack::Test::Session.new(Rails.application)
      secret = Webhooks::Signature.secret
      events = JSON.parse(File.read(Rails.root.join(FIXTURE)))
      tamper_index = @tamper ? events.size / 2 : nil
      tally = Hash.new(0)

      events.each_with_index do |event, index|
        body = JSON.generate(event)
        signature = Webhooks::Signature.sign(body, secret)
        signature = signature.reverse if index == tamper_index
        session.post("/webhooks/delivery", body, "HTTP_HOST" => "localhost", "CONTENT_TYPE" => "application/json", "HTTP_X_WEBHOOK_SIGNATURE" => signature)
        status = session.last_response.status == 200 ? JSON.parse(session.last_response.body)["status"] : "rejected_signature_#{session.last_response.status}"
        tally[status] += 1
      end

      InboundEvent.pending.order(:id).find_each { |event| InboundEvents::Process.call(event.id) }
      LocalState.apply(Rails.root.join(LOCAL_STATE))
      Result.new(tally)
    end
  end
end
