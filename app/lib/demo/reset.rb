module Demo
  class Reset
    TABLES = [ Transition, DeliveryCase, InboundEvent, RejectedRequest, IngestionCounter, OrganizationSettings ].freeze

    def self.call
      ActiveRecord::Base.transaction { TABLES.each(&:delete_all) }
    end
  end
end
