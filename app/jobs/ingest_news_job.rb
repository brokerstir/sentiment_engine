class IngestNewsJob < ApplicationJob
  queue_as :default

  def perform
    articles = Providers::NewsdataArticleProvider.new.fetch
    articles.each do |article|
      # Only analyze if it hasn't been analyzed yet (idempotency)
      unless article.article_analyses.any?
        AnalyzeArticleJob.perform_later(article)
      end
    end
  end
end
