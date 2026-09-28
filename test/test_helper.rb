ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/facts_builder"
require_relative "support/facts_generator"
require_relative "support/clock_guard"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    include FactsBuilder
    include ClockGuard


    def create_case(**overrides)
      attributes = {
        reward_id: "rw_#{SecureRandom.hex(4)}",
        channel: "email",
        reason: "mailbox_unavailable",
        retryable: true,
        expires_at: Time.utc(2027, 1, 1),
        latest_event_at: Time.utc(2026, 9, 28, 10, 0, 0)
      }.merge(overrides)
      DeliveryCase.new(attributes).tap do |delivery_case|
        delivery_case.commit_change!(action: "delivery_failed", actor_type: "system", cause_type: "inbound_event", cause_id: SecureRandom.uuid) { }
      end
    end
  end
end
