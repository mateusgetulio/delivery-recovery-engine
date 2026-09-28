namespace :demo do
  desc "Replay the fixture through the real webhook path (TAMPER=1 corrupts one signature)"
  task replay: :environment do
    result = Demo::Replay.call(tamper: ENV["TAMPER"].present?)
    result.tally.each { |status, count| puts "#{status.ljust(20)} #{count}" }
    puts "cases #{DeliveryCase.count}, transitions #{Transition.count}, pending #{InboundEvent.pending.count}, failed #{InboundEvent.where(status: 'failed').count}"
  end

  desc "Remove every case, event, transition and counter"
  task reset: :environment do
    Demo::Reset.call
    puts "reset"
  end
end
