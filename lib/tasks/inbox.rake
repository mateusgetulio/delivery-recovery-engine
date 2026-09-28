namespace :inbox do
  desc "Enqueue processing for inbound events still pending after the recovery window"
  task process_pending: :environment do
    puts "enqueued #{InboundEvents::EnqueuePending.call} pending events"
  end
end
