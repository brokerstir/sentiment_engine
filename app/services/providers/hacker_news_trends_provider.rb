require "rss"
require "open-uri"

module Providers
  class HackerNewsTrendsProvider
    FEEDS = {
      front_page: "https://hnrss.org/frontpage",
      show_hn:    "https://hnrss.org/show",
      ask_hn:     "https://hnrss.org/ask"
    }.freeze

    # Your expanded 2026 Juice List
    JUICY_KEYWORDS = %w[
      unmask fbi warfare conflict laws compromise protest
      lawsuit epstein protests
      ethics surveillance iran ice
      crisis threat senate potus affair
      censorship investigation arrest
      lawsuit propaganda trump congress war
    ].freeze

    def fetch
      all_trends = []
      puts "\n--- [STARTING SANITIZED & FILTERED HN TREND AUDIT] ---"

      FEEDS.each do |label, url|
        print "DEBUG [HackerNews]: Fetching #{label.to_s.upcase}..."

        begin
          response = URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 5).read
          feed = RSS::Parser.parse(response, false)

          items = feed.items.first(40)
          puts " Scanned #{items.size} headlines."

          # In app/services/providers/hacker_news_trends_provider.rb

          category_trends = items.map do |item|
            clean_name = item.title
                             .gsub(/^(Show|Ask|Launch)\s+HN:\s+/i, "")
                             .gsub(/\(\d{4}\)/, "")
                             .gsub(/\[video\]/i, "")
                             .gsub(/\.{2,}/, "") # <--- NEW: Strips 2 or more consecutive dots
                             .strip
                             .gsub(/^–\s+/, "")
                             .gsub(/[[:punct:]]+$/, "") # <--- PRO MOVE: Strips any trailing punctuation (!, ?, ., -)

            {
              name: clean_name,
              source: "Hacker News (#{label.to_s.titleize})"
            }
          end
          all_trends.concat(category_trends)
        rescue => e
          puts " FAILED: #{e.message}"
        end
      end

      # Filter by the Juice List
      results = all_trends.select do |trend|
        JUICY_KEYWORDS.any? { |word| trend[:name].downcase.include?(word) }
      end

      # Unique by name
      final_results = results.uniq { |t| t[:name].downcase }

      final_results.each do |t|
        puts "   >> [JUICY MATCH] #{t[:name]}"
      end

      puts "--- [HN AUDIT COMPLETE: #{final_results.size} TRENDS] ---\n\n"
      final_results
    end
  end
end
