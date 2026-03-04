# app/services/trend_context_service.rb
require 'rss'
require 'open-uri'
require 'action_view' # Needed for strip_tags

class TrendContextService
  # We include this to easily clean HTML from the RSS description
  include ActionView::Helpers::SanitizeHelper

  def self.call(trend_name)
    new(trend_name).call
  end

  def initialize(trend_name)
    @trend_name = CGI.escape(trend_name)
  end

  def call
    url = "https://news.google.com/rss/search?q=#{@trend_name}&hl=en-US&gl=US&ceid=US:en"
    context_blocks = []

    URI.open(url) do |rss|
      feed = RSS::Parser.parse(rss)

      context_blocks = feed.items.first(5).map do |item|
        # Google RSS descriptions often contain HTML tables and links.
        # strip_tags gives the LLM clean, high-signal text.
        clean_description = strip_tags(item.description)

        "HEADLINE: #{item.title} | SUMMARY: #{clean_description}"
      end
    end

    context_blocks.join("\n---\n")
  rescue => e
    Rails.logger.error "Context Fetcher Error: #{e.message}"
    "No recent news context available."
  end
end