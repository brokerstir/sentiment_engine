class Trend < ApplicationRecord
  has_many :source_items, dependent: :destroy
  has_many :sentiment_analyses, through: :source_items

  enum :status, { pending: 0, completed: 1, failed: 2 }, default: :pending

  # Senior Move: Scopes for the Dashboard
  scope :hot, -> { where(status: :completed).order(intensity_heat: :desc) }

  def chart_data
    sentiment_analyses.map do |sa|
      {
        label: "#{sa.llm_model} | #{sa.source_item.headline.truncate(40)}",
        # NEW MAPPING: X is Bias (-1 to 1), Y is Sentiment Score (-1 to 1)
        data: [ { x: sa.bias, y: sa.score, intensity: sa.intensity } ],
        backgroundColor: sa.llm_model.downcase.include?("gemini") ? "rgba(66, 133, 244, 0.6)" : "rgba(0, 0, 0, 0.7)",
        borderColor: sa.llm_model.downcase.include?("gemini") ? "#4285F4" : "#000000",
        # Bubble size now represents the Emotional Intensity
        pointRadius: (sa.intensity * 12) + 3,
        pointHoverRadius: 16
      }
    end
  end

  def reasoning_groups
    source_items.includes(:sentiment_analyses).map do |item|
      {
        headline: item.headline,
        url: item.url,
        analyses: item.sentiment_analyses.index_by(&:llm_model)
      }
    end
  end

  # Helper for UI badge color
  def heat_color
    return "gray" if pending?
    intensity_heat > 0.6 ? "red" : "orange"
  end
end
