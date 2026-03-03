class Trend < ApplicationRecord
  has_many :sentiment_analyses, dependent: :destroy

  # 0: pending (just fetched), 1: completed (AI analyzed), 2: failed
  enum :status, { pending: 0, completed: 1, failed: 2 }, default: :pending

  validates :name, presence: true, uniqueness: true
  validates :source, presence: true
end
