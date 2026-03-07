require "rss"
require "open-uri"

module Providers
  class HackerNewsTrendsProvider
    FEEDS = {
      front_page: "https://hnrss.org/frontpage",
      show_hn:    "https://hnrss.org/show",
      ask_hn:     "https://hnrss.org/ask"
    }.freeze

    # Word-boundary safe keywords
    JUICY_KEYWORDS = %w[
      unmask fbi warfare laws protest lawsuit epstein ethics
      surveillance iran ice crisis threat senate potus affair
      censorship investigation arrest propaganda trump war
      program computer data encryption blockchain
    ].freeze

    def fetch
      all_trends = []
      puts "\n--- [STARTING SANITIZED & FILTERED HN TREND AUDIT] ---"

      FEEDS.each do |label, url|
        print "DEBUG [HackerNews]: Fetching #{label.to_s.upcase}..."

        begin
          response = URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 5).read
          feed = RSS::Parser.parse(response, false)
          items = feed.items.first(70) # Scanned more to find matches
          puts " Scanned #{items.size} headlines."

          category_trends = items.map do |item|
            # 1. Handle both literal dots and the single-character ellipsis (…)
            name = item.title.to_s.gsub(/(\.{3,}|…)$/, "").strip

            # 2. Strip HN Tags and formatting
            clean_name = name.gsub(/^(Show|Ask|Launch)\s+HN:\s+/i, "")
                             .gsub(/\(\d{4}\)/, "")
                             .gsub(/\[video\]/i, "")
                             .gsub(/^–\s+/, "")
                             .gsub(/[[:punct:]]+$/, "") # Strip trailing punctuation
                             .strip

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

      # THE FIX: Match whole words only to prevent "colony" matching "laws"
      # And ensure name isn't empty after sanitization
      results = all_trends.select do |trend|
        next false if trend[:name].blank?

        # Regex \b ensures we match "war" but not "software"
        JUICY_KEYWORDS.any? do |word|
          trend[:name].downcase =~ /\b#{Regexp.escape(word)}\b/
        end
      end

      final_results = results.uniq { |t| t[:name].downcase }

      final_results.each do |t|
        puts "   >> [JUICY MATCH] #{t[:name]}"
      end

      puts "--- [HN AUDIT COMPLETE: #{final_results.size} TRENDS] ---\n\n"
      final_results
    end
  end
end
