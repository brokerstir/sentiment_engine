class Trend < ApplicationRecord
  has_many :source_items, dependent: :destroy
  has_many :sentiment_analyses, through: :source_items

  enum :status, { pending: 0, completed: 1, failed: 2 }, default: :pending

  def chart_data
    sentiment_analyses.map do |sa|
      {
        label: "#{sa.llm_model} | #{sa.source_item.headline.truncate(30)}",
        data: [{ x: sa.score, y: sa.intensity }],
        # Gemini Blue vs Grok Black
        backgroundColor: sa.llm_model.downcase.include?('gemini') ? 'rgba(66, 133, 244, 0.7)' : 'rgba(0, 0, 0, 0.8)',
        borderColor: sa.llm_model.downcase.include?('gemini') ? '#4285F4' : '#000000',
        pointRadius: 6,
        pointHoverRadius: 10
      }
    end
  end
end