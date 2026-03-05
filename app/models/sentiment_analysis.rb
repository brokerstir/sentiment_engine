class SentimentAnalysis < ApplicationRecord
  belongs_to :source_item

  validates :llm_model, :reasoning, presence: true

  # Score: -1 (Negative) to 1 (Positive)
  validates :score, numericality: {
    greater_than_or_equal_to: -1.0,
    less_than_or_equal_to: 1.0
  }

  # Intensity: 0 (Apathy) to 1 (Extreme Passion)
  validates :intensity, numericality: {
    greater_than_or_equal_to: 0.0,
    less_than_or_equal_to: 1.0
  }

  validates :reasoning, presence: true
end

