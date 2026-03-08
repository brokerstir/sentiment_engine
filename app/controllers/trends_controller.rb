class TrendsController < ApplicationController
  def index
    # Filter: Only show trends where the AI models actually have something to fight about.
    @trends = Trend.completed
                   .where("bias_disagreement >= ?", 0.13)
                   .order(created_at: :desc)
                   .limit(500)
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
