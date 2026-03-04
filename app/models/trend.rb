class Trend < ApplicationRecord
  has_many :sentiment_analyses, dependent: :destroy

  # 0: pending (just fetched), 1: completed (AI analyzed), 2: failed
  enum :status, { pending: 0, completed: 1, failed: 2 }, default: :pending

  validates :name, presence: true, uniqueness: true
  validates :source, presence: true

  def chart_data
    sentiment_analyses.map do |sa|
      {
        label: "#{sa.llm_model}: #{sa.headline&.truncate(30)}",
        data: [{
          x: sa.score,
          y: sa.intensity,
          reasoning: sa.reasoning,
          url: sa.url,
          headline: sa.headline
        }],
        backgroundColor: sa.llm_model.include?("gemini") ? "rgba(66, 133, 244, 0.7)" : "rgba(0, 0, 0, 0.7)",
        borderColor: sa.llm_model.include?("gemini") ? "#4285F4" : "#000000",
        pointRadius: 8,
        pointHoverRadius: 12
      }
    end
  end
end
