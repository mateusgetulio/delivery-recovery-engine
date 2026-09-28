module InboundEvents
  class EnqueuePending
    WINDOW = 30.seconds

    def self.call(now: Time.current)
      ids = InboundEvent.pending.where(received_at: ..(now - WINDOW)).pluck(:id)
      ids.each { |id| ProcessInboundEventJob.perform_later(id) }
      ids.size
    end
  end
end
