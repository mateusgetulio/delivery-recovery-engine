namespace :demo do
  desc "Replay the fixture through the real webhook path (TAMPER=1 corrupts one signature)"
  task replay: :environment do
    require "rack/test"
    session = Rack::Test::Session.new(Rails.application)
    secret = Webhooks::Signature.secret
    events = JSON.parse(File.read(Rails.root.join("fixtures/delivery_events.json")))
    tamper_index = ENV["TAMPER"].present? ? events.size / 2 : nil
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
    Demo::LocalState.apply(Rails.root.join("fixtures/local_state.json"))

    tally.each { |status, count| puts "#{status.ljust(20)} #{count}" }
    puts "cases #{DeliveryCase.count}, transitions #{Transition.count}, pending #{InboundEvent.pending.count}, failed #{InboundEvent.where(status: 'failed').count}"
  end

  desc "Remove every case, event, transition and counter"
  task reset: :environment do
    [ Transition, DeliveryCase, InboundEvent, RejectedRequest, IngestionCounter, OrganizationSettings ].each(&:delete_all)
    puts "reset"
  end
end
