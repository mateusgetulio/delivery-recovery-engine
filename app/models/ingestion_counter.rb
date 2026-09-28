class IngestionCounter < ApplicationRecord
  def self.current
    find_or_create_by!(id: 1)
  rescue ActiveRecord::RecordNotUnique
    find(1)
  end

  def self.count_rejected_signature!
    current.increment!(:rejected_signatures)
  end
end
