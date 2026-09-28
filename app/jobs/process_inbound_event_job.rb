class ProcessInboundEventJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::StaleObjectError, wait: 1.second, attempts: 5

  def perform(inbound_event_id)
    InboundEvents::Process.call(inbound_event_id)
  end
end
