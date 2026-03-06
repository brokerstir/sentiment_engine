# app/services/trend_context_service.rb
class TrendContextService
  USER_AGENT = "SentimentEngine/1.0 (RoR-#{rand(100)})"

  # We now pass the WHOLE trend object, not just the name
  def self.call(trend)
    new(trend).call
  end

  def initialize(trend)
    @trend = trend
    @trend_name = trend.name
  end

  def call
    puts "DEBUG [Context]: Multi-Source Mix Strategy for '#{@trend_name}'"

    # 1. Fetch everything upfront (cached in variables for this method call)
    # We take slightly more than needed so we have a 'buffer' for the overflow logic
    all_hn     = fetch_hacker_news.first(3) # Max 3
    all_reddit = fetch_reddit_posts.first(1) # Max 1
    all_google = fetch_google_news.first(6) # Fetch extra for fallback slots

    # 2. Start the Mix with the "Ideal" baseline
    # 2 Hacker, 1 Reddit, 3 Google
    results = []
    results += all_hn.first(2)
    results += all_reddit.first(1)
    results += all_google.first(3)

    # 3. OVERFLOW LOGIC: Backfill if we are under 6
    if results.size < 6
      # Try to grab that 3rd Hacker News item if it exists and we have room
      if all_hn.size > 2 && results.size < 6
        puts "DEBUG [Context]: Backfilling with extra HN item"
        results << all_hn[2]
      end

      # Finally, dump the rest into Google (up to the max of 4 Google total)
      if results.size < 6
        existing_urls = results.map { |r| r[:url] }
        google_remaining = all_google.reject { |g| existing_urls.include?(g[:url]) }

        puts "DEBUG [Context]: Backfilling with #{6 - results.size} extra Google items"
        results += google_remaining.first(6 - results.size)
      end
    end

    # 4. Final Guard: Ensure 100% uniqueness and absolute cap of 6
    final_results = results.uniq { |r| r[:url] }.first(6)

    puts "DEBUG [Context]: Final Mix -> HN:#{final_results.count { |r| r[:headline].include?('[HN]') }} | " \
         "R:#{final_results.count { |r| r[:headline].include?('[Reddit]') }} | " \
         "G:#{final_results.count { |r| r[:headline].include?('[News]') }}"

    final_results
  end

  private

  # The "Search Engine Optimizer": Strips dots, trailing junk, and limits to 6 words.
  def search_query
    @trend_name.gsub(/\.{2,}/, "")         # Remove ellipses
               .gsub(/[[:punct:]]+$/, "")  # Remove trailing punctuation
               .split(/\s+/)               # Split by whitespace
               .first(6)                   # Take first 6 words
               .join(" ")                  # Rejoin
  end

  def fetch_google_news
    # Use search_query to ensure Google doesn't get confused by RSS truncated dots
    url = "https://news.google.com/rss/search?q=#{CGI.escape(search_query)}&hl=en-US&gl=US&ceid=US:en"
    parse_rss(url, source_prefix: "[News]")
  end

  def fetch_reddit_posts
    # Searching all of Reddit using the optimized query
    url = "https://www.reddit.com/search.rss?q=#{CGI.escape(search_query)}&sort=relevance&t=day"
    headers = { "User-Agent" => USER_AGENT, "Accept" => "application/xml" }
    parse_rss(url, source_prefix: "[Reddit]", headers: headers)
  end

  def fetch_hacker_news
    # Algolia works best with the first few high-impact keywords
    url = "https://hn.algolia.com/api/v1/search?query=#{CGI.escape(search_query)}&tags=story&hitsPerPage=10"

    begin
      response = URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 5).read
      data = JSON.parse(response)

      data["hits"].map do |hit|
        {
          headline: "[HN] #{hit['title']}".truncate(120),
          url: "https://news.ycombinator.com/item?id=#{hit['objectID']}",
          summary: "HN Points: #{hit['points']} | Comments: #{hit['num_comments']}. Discussion: https://news.ycombinator.com/item?id=#{hit['objectID']}"
        }
      end
    rescue => e
      puts "DEBUG [HN ERROR]: #{e.message}"
      []
    end
  end

  def parse_rss(url, source_prefix:, headers: {})
    sanitizer = Rails::Html::FullSanitizer.new
    URI.open(url, headers.merge(read_timeout: 5)) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.map do |item|
        clean_title = item.title.to_s.gsub(/<[^>]*>/, "").strip

        # Reddit and Google RSS use different fields for the summary
        raw_body = if item.respond_to?(:description) && item.description
                     item.description.to_s
        elsif item.respond_to?(:summary) && item.summary
                     item.summary.to_s
        else
                     ""
        end

        {
          headline: "#{source_prefix} #{clean_title}".truncate(120),
          url: item.link.to_s,
          summary: sanitizer.sanitize(raw_body).strip.truncate(400)
        }
      end
    end
  rescue => e
    puts "DEBUG [#{source_prefix} ERROR]: #{e.message}"
    []
  end
end
