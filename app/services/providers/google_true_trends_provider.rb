require "rss"
require "open-uri"

module Providers
  class GoogleTrueTrendsProvider
    # RSS endpoint for US Daily Trends
    # pn=p1 is the legacy parameter for US, geo=US is the modern equivalent
    RSS_URL = "http://www.google.com/trends/hottrends/atom/feed?pn=p1"

    def fetch
      all_trends = []
      puts "\n--- [STARTING GOOGLE TRENDS RSS AUDIT] ---"
      puts "DEBUG [GoogleTrends]: Requesting RSS Feed: #{RSS_URL}"

      begin
        # Google RSS still requires a User-Agent or it may return 403
        URI.open(RSS_URL, "User-Agent" => "Mozilla/5.0", read_timeout: 10) do |rss|
          feed = RSS::Parser.parse(rss)

          if feed.nil? || feed.items.empty?
            puts "WARN [GoogleTrends]: RSS Feed is empty or unparseable."
            return []
          end

          puts "DEBUG [GoogleTrends]: Successfully parsed #{feed.items.size} trends from RSS."

          all_trends = feed.items.map do |item|
            trend_name = item.title.to_s.strip

            # Google adds 'approx_traffic' in a custom namespace <ht:approx_traffic>
            # We can extract it via the 'ht_approx_traffic' method if the parser picks it up,
            # or just skip it for the discovery phase.
            traffic = item.respond_to?(:ht_approx_traffic) ? item.ht_approx_traffic : "Unknown"

            puts "    >> [TREND] #{trend_name.ljust(25)} | Approx Traffic: #{traffic}"

            {
              name: trend_name,
              source: "Google Trends (RSS)"
            }
          end
        end

      rescue OpenURI::HTTPError => e
        puts "CRITICAL ERROR [GoogleTrends]: HTTP Error #{e.message}. The RSS endpoint might be down."
      rescue => e
        puts "CRITICAL ERROR [GoogleTrends]: #{e.class} - #{e.message}"
      end

      results = all_trends.uniq { |t| t[:name].downcase }
      puts "--- [AUDIT COMPLETE: #{results.size} TRENDS DISCOVERED] ---\n\n"
      results
    end
  end
end