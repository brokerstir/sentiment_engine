class TrendsController < ApplicationController
  def index
    # Start with the "Juicy" baseline
    @trends = Trend.completed.where("bias_disagreement >= 0.13")

    # Apply specific "Battle Tier" filters
    @trends = case params[:filter]
    when "consensus"     then @trends.where(bias_disagreement: 0.13..0.15)
    when "dissent"       then @trends.where(bias_disagreement: 0.15..0.6)
    when "contradiction" then @trends.where(bias_disagreement: 0.6..1.2)
    when "polarized"     then @trends.where("bias_disagreement >= 1.2")
    else @trends # Show all juicy trends
    end

    @trends = @trends.order(created_at: :desc).limit(500)
  end

  def show
    # Scope to completed to prevent manual URL manipulation for pending trends
    @trend = Trend.completed
                  .includes(source_items: :sentiment_analyses)
                  .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to trends_path, alert: "That trend analysis is still in progress or does not exist."
  end
end
