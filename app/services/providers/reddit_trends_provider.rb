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

      feed.items.first(5).map do |item| # Scanned 10 for better variety
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
      # 1. Immediate Nuke: Kill all forms of ellipses and 2+ dots anywhere
      # to prevent them from interfering with word-boundary truncation.
      # Includes Unicode ellipsis (…), literal dots (...), and encoded entities.
      text = text.gsub(/[…\.\s]{2,}/, " ").strip

      # 2. Kill the Reddit Meta-trash
      text = text.gsub(/(\/r\/WorldNews|Live Thread|Discussion Thread|Thread #\d+|:)/i, "").strip

      # 3. Clean up leading/trailing quotes
      text = text.gsub(/^[‘'"]|[’'"]$/, "").strip

      # 4. Truncate to a solid length.
      # We use a literal space as the separator to be safe.
      text = text.truncate(60, separator: " ", omission: "")

      # 5. THE AGGRESSIVE FINISHER:
      # Remove ANY trailing non-word/non-number characters.
      # This nukes dots, dashes, spaces, and commas at the end of the string.
      text.gsub!(/[^\w\d]+$/, "")

      text.strip
    end
  end
end
