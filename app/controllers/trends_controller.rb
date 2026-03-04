class TrendsController < ApplicationController
  def index
    # .includes prevents N+1 queries for the chart data
    @trends = Trend.where(status: "completed").includes(:sentiment_analyses).order(created_at: :desc)
  end
end