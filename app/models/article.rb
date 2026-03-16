class Article < ApplicationRecord
  has_many :article_analyses, dependent: :delete_all

  validates :title, :link, presence: true
  validates :link, uniqueness: true

  def update_disagreement_score!
    return update_column(:disagreement_score, 0.0) if article_analyses.count < 2

    # Assuming we are comparing Gemini and Grok
    a1 = article_analyses.find_by(llm_name: "gemini")
    a2 = article_analyses.find_by(llm_name: "grok")

    return unless a1 && a2

    score = calculate_polarity_pivot(a1, a2)
    update_column(:disagreement_score, score)
  end

  def conflict_label
    case disagreement_score
    when 0.0..0.5
      "Consensus"
    when 0.5..1.5
      "Minor Conflict"
    when 1.5..3.0
      "Strong Conflict"
    else
      "Polarization"
    end
  end

  def conflict_color
    case disagreement_score
    when 0.0..0.5
      "text-green-600 bg-green-50 border-green-200"
    when 0.5..1.5
      "text-yellow-600 bg-yellow-50 border-yellow-200"
    when 1.5..3.0
      "text-orange-600 bg-orange-50 border-orange-200"
    else
      "text-red-600 bg-red-50 border-red-200"
    end
  end

  def conflict_style
    case disagreement_score
    when 0.0..0.5
      { bg: "#f0fdf4", text: "#16a34a", border: "#bbf7d0" } # Green
    when 0.5..1.5
      { bg: "#fefce8", text: "#ca8a04", border: "#fef08a" } # Yellow
    when 1.5..3.0
      { bg: "#fff7ed", text: "#ea580c", border: "#fed7aa" } # Orange
    else
      { bg: "#fef2f2", text: "#dc2626", border: "#fee2e2" } # Red
    end
  end

  private

  def calculate_polarity_pivot(a1, a2)
    # 1. Bias Polarity Penalty (Weight 2.0 if signs differ, 1.0 if same)
    bias_multiplier = (a1.bias * a2.bias < 0) ? 2.0 : 1.0
    bias_delta = (a1.bias - a2.bias).abs * bias_multiplier

    # 2. Evaluation Polarity Penalty
    eval_multiplier = (a1.evaluation * a2.evaluation < 0) ? 2.0 : 1.0
    eval_delta = (a1.evaluation - a2.evaluation).abs * eval_multiplier

    # 3. Heat Delta (Simple intensity difference)
    heat_delta = (a1.heat - a2.heat).abs

    # The Math: Weighted Euclidean Distance
    # Formula: sqrt( (bias_d)^2 + (eval_d)^2 + (heat_d)^2 )
    Math.sqrt((bias_delta**2) + (eval_delta**2) + (heat_delta**2)).round(4)
  end
end
