# app/services/providers/google_trends_provider.rb
require "rss"
require "open-uri"

module Providers
  class GoogleTrendsProvider
    # These are the high-intensity 2026 Topic Tokens
    TOPICS = {
      us_news:  "CAAqIggKIhxDQkFTRHdvSkwyMHZNRGxqTjNjd0VnSmxiaWdBUAE",
      world:    "CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB"
      # health:   "CAAqIQgKIhtDQkFTRGdvSUwyMHZNR3QwTlRFU0FtVnVLQUFQAQ"
    }

    def fetch
      all_trends = []
      puts "\n--- [STARTING 2026 HIGH-HEAT TOPIC AUDIT] ---"

      TOPICS.each do |label, topic_id|
        print "DEBUG [GoogleNews]: Fetching #{label.to_s.upcase}..."

        url = "https://news.google.com/rss/topics/#{topic_id}?hl=en-US&gl=US&ceid=US:en"

        begin
          # Mask as a modern browser to ensure we get the full feed
          response = URI.open(url,
            "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            read_timeout: 5
          ).read

          feed = RSS::Parser.parse(response, false)
          items = feed.items.first(3) # Auditing top 8 per category
          puts " Found #{items.size} headlines."

          category_trends = items.map do |item|
            # We want short, searchable trend names.
            # We take the first 4 words and strip the trailing ' - Source Name'
            trend_name = item.title.gsub(/ - .*/, "").split(" ").first(5).join(" ").strip

            puts "   >> [#{label.to_s.titleize}] #{trend_name}"
            {
              name: trend_name,
              source: "Google News (#{label.to_s.titleize})"
            }
          end

          all_trends.concat(category_trends)
        rescue => e
          puts " FAILED: #{e.message}"
        end
      end

      # Unique by downcased name to ensure a clean list
      results = all_trends.uniq { |t| t[:name].downcase }
      puts "--- [AUDIT COMPLETE: #{results.size} UNIQUE JUICY TRENDS] ---\n\n"
      results
    end
  end
end
