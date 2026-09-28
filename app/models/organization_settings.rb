class OrganizationSettings < ApplicationRecord
  def self.current(lock: false)
    scope = lock ? self.lock : all
    scope.find_or_create_by!(id: 1)
  rescue ActiveRecord::RecordNotUnique
    scope.find(1)
  end
end
