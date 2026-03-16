class ArticlesController < ApplicationController
  def index
    # 1. Get IDs of articles that have exactly 2 or more analyses in the last 4 days
    valid_article_ids = Article.joins(:article_analyses)
                               .where(pub_date: 3.days.ago.beginning_of_day..Time.current)
                               .group("articles.id")
                               .having("count(article_analyses.id) >= 2")
                               .pluck(:id)

    # 2. Load those specific articles with all their analyses properly eager-loaded
    @articles = Article.includes(:article_analyses)
                   .where(id: valid_article_ids)
                   .where("disagreement_score > ?", 0.3)
                   .order(created_at: :desc)

    session[:revealed_ids] ||= []
    @revealed_ids = session[:revealed_ids]
  end

  def show
    @article = Article.find(params[:id])
  end

  def reveal
    session[:revealed_ids] ||= []
    session[:revealed_ids] << params[:id].to_i unless session[:revealed_ids].include?(params[:id].to_i)
    head :ok
  end

  def reset_game
    session.delete(:revealed_ids)
    redirect_to articles_path, notice: "Game reset! All models re-masked."
  end
end


def index
  # 1. Get IDs of articles that have exactly 2 or more analyses in the last 4 days
  valid_article_ids = Article.joins(:article_analyses)
                             .where(pub_date: 3.days.ago.beginning_of_day..Time.current)
                             .group("articles.id")
                             .having("count(article_analyses.id) >= 2")
                             .pluck(:id)

  # 2. Load those specific articles with all their analyses properly eager-loaded
  @articles = Article.includes(:article_analyses)
                     .where(id: valid_article_ids)
                     .order(disagreement_score: :desc)

  @revealed_ids = session[:revealed_ids] ||= []
end
