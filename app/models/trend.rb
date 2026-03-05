class Trend < ApplicationRecord
  has_many :source_items, dependent: :destroy
  has_many :sentiment_analyses, through: :source_items

  enum :status, { pending: 0, completed: 1, failed: 2 }, default: :pending

  def chart_data
    sentiment_analyses.includes(:source_item).map do |sa|
      {
        label: "#{sa.llm_model}: #{sa.source_item.headline.truncate(20)}",
        data: [{ x: sa.score, y: sa.intensity }],
        backgroundColor: sa.llm_model.include?("gemini") ? "rgba(66, 133, 244, 0.7)" : "rgba(0, 0, 0, 0.7)"
      }
    end
  end
end