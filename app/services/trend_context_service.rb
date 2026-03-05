# app/services/trend_context_service.rb
require "rss"
require "open-uri"

class TrendContextService
  # Senior Move: Access the sanitizer without needing to mix in instance helpers
  @sanitizer = Rails::Html::FullSanitizer.new

  def self.call(trend_name)
    new(trend_name).call
  end

  def initialize(trend_name)
    @trend_name = CGI.escape(trend_name)
  end

  def call
    url = "https://news.google.com/rss/search?q=#{@trend_name}&hl=en-US&gl=US&ceid=US:en"

    # Use self.class to access the class-level sanitizer
    sanitizer = Rails::Html::FullSanitizer.new

    URI.open(url) do |rss|
      feed = RSS::Parser.parse(rss)

      feed.items.first(3).map do |item|
        {
          headline: item.title,
          url: item.link,
          # High-signal summary for the LLM
          summary: sanitizer.sanitize(item.description).truncate(500)
        }
      end
    end
  rescue => e
    Rails.logger.error "Context Fetcher Error: #{e.message}"
    []
  end
end