class AnalyzeArticleJob < ApplicationJob
  queue_as :default

  # Senior Practice: Retry if the LLM API is rate limited or down
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 3

  def perform(article)
    ArticleAnalyzerService.call(article)
  end
end
