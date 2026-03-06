# app/services/providers/reddit_trends_provider.rb
require "rss"
require "open-uri"

module Providers
  class RedditTrendsProvider
    RSS_URL = "https://www.reddit.com/r/worldnews/hot/.rss"
    USER_AGENT = "SentimentEngine-v1-#{rand(100)}"

    def fetch
      puts "DEBUG [Reddit]: Fetching WorldNews..."
      response = URI.open(RSS_URL, "User-Agent" => USER_AGENT).read
      feed = RSS::Parser.parse(response)
      sanitizer = Rails::Html::FullSanitizer.new

      feed.items.first(3).map do |item| # Bumping to 10 for better variety
        raw_title = sanitizer.sanitize(item.title.to_s)
        punchy_name = extract_punchy_name(raw_title)

        puts "   >> [Reddit Match] #{punchy_name}"

        {
          name: punchy_name,
          source: "Reddit WorldNews"
        }
      end
    rescue => e
      puts "DEBUG [Reddit]: ERROR -> #{e.message}"
      []
    end

    private

    def extract_punchy_name(text)
      # 1. Kill the Reddit Meta-trash
      text = text.gsub(/(\/r\/WorldNews|Live Thread|Discussion Thread|Thread #\d+|:)/i, "").strip

      # 2. Nuke the trailing dots (2 or more) and trailing punctuation
      # This fixes the "Swarm - Program a colony... " issue
      text = text.gsub(/\.{2,}/, "").gsub(/[[:punct:]]+$/, "").strip

      # 3. Clean up leading/trailing quotes
      text = text.gsub(/^[‘'"]|[’'"]$/, "").strip

      # 4. Truncate to a solid, searchable length
      text.truncate(60, separator: /\s/, omission: "")
    end
  end
end
