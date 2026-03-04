require "rss"
require "open-uri"

module Providers
  class GoogleTrendsProvider
    # Fetches the top daily search trends from Google
    RSS_URL = "https://trends.google.com/trending/rss?geo=US"

    def fetch
      response = URI.open(RSS_URL).read
      feed = RSS::Parser.parse(response)

      # Use .first(n) to cap the intake, e.g., only the top 5 trends
      feed.items.first(5).map do |item|
        {
          name: item.title,
          source: "Google Trends"
        }
      end
    rescue => e
      Rails.logger.error "Google Trends Provider Error: #{e.message}"
      []
    end
  end
end
