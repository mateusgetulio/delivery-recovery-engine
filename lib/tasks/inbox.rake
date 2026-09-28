namespace :inbox do
  desc "Enqueue processing for inbound events still pending after 30 seconds"
  task process_pending: :environment do
    ids = InboundEvent.pending.where(received_at: ..30.seconds.ago).pluck(:id)
    ids.each { |id| ProcessInboundEventJob.perform_later(id) }
    puts "enqueued #{ids.size} pending events"
  end
end
