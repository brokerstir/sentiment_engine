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

      feed.items.first(5).map do |item|
        # 1. Clean the title object into a plain string
        raw_title = sanitizer.sanitize(item.title.to_s)

        # 2. Extract a "Punchy" 1-3 word name
        punchy_name = extract_punchy_name(raw_title)

        puts "---"
        puts "RAW: #{raw_title.truncate(50)}"
        puts "CLEAN: #{punchy_name}"

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

      # 2. Clean up leading/trailing punctuation (like those ‘ quotes)
      text = text.gsub(/^[‘'"]|[’'"]$/, "").strip

      # 3. Take up to 60 chars, but don't slice a word in half
      # This feels more "Newsworthy" than 3 random words.
      text.truncate(30, separator: /\s/)
    end
  end
end
