class TrendsController < ApplicationController
  def index
    # Only show completed trends to keep the index clean
    @trends = Trend.completed.order(created_at: :desc)
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