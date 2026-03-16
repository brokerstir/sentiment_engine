class ArticleAnalysis < ApplicationRecord
  belongs_to :article

  validates :llm_name, presence: true
  validates :bias, inclusion: { in: -1.0..1.0 }, allow_nil: true
  validates :heat, inclusion: { in: 0.0..1.0 }, allow_nil: true
  validates :evaluation, inclusion: { in: -1.0..1.0 }, allow_nil: true

  after_commit :refresh_article_disagreement_score

  def bias_label
    case bias
    when -1.0..-0.7 then "Far Left"
    when -0.7..-0.2 then "Leans Left"
    when -0.2..0.2  then "Centrist"
    when 0.2..0.7   then "Leans Right"
    when 0.7..1.0   then "Far Right"
    else "Unknown"
    end
  end

  def heat_label
    case heat
    when 0.0..0.2 then "Clinical"
    when 0.2..0.5 then "Measured"
    when 0.5..0.8 then "Inflammatory"
    when 0.8..1.0 then "Sensationalist"
    else "Neutral"
    end
  end

  def eval_label
    case evaluation
    when -1.0..-0.6 then "Scathing"
    when -0.6..-0.2 then "Critical"
    when -0.2..0.2  then "Balanced"
    when 0.2..0.6   then "Supportive"
    when 0.6..1.0   then "Laudatory"
    else "N/A"
    end
  end

  private

  def refresh_article_disagreement_score
    return if article.nil? || article.destroyed? || article.marked_for_destruction?

    article.update_disagreement_score!
  end
end
