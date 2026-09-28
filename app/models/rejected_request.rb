class RejectedRequest < ApplicationRecord
  validates :raw_body, :error, presence: true
end
