class SentimentAnalysis < ApplicationRecord
  belongs_to :trend

  validates :llm_model, presence: true
  # Score should be between -1.0 (very negative) and 1.0 (very positive)
  validates :score, numericality: { greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0 }
  validates :reasoning, presence: true
end