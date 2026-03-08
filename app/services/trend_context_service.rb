# app/services/trend_context_service.rb
class TrendContextService
  USER_AGENT = "SentimentEngine/1.0 (RoR-#{rand(100)})"

  def self.call(trend)
    new(trend).call
  end

  def initialize(trend)
    @trend = trend
    @trend_name = trend.name
  end

  def call
    # DEBUG: Ensure we know the birthplace and the generated query
    query = search_query
    puts "\nDEBUG [Context]: --- STARTING CONTEXT FETCH ---"
    puts "DEBUG [Context]: Trend: '#{@trend_name}'"
    puts "DEBUG [Context]: Provider: '#{@trend.source_provider}'"
    puts "DEBUG [Context]: Optimized Query: '#{query}'"

    results = case @trend.source_provider
    when "hacker_news" then fetch_hacker_news(query)
    when "reddit"      then fetch_reddit_posts(query)
    when "google"      then fetch_google_news(query)
    else fetch_google_news(query)
    end

    puts "DEBUG [Context]: Raw Results Found: #{results.size}"

    if results.size < 3
      puts "DEBUG [Context]: REJECTED - Only found #{results.size} items (Minimum 3 required for Trend ID: #{@trend.id})"
      return []
    end

    final_results = results.uniq { |r| r[:url] }.first(5)
    puts "DEBUG [Context]: SUCCESS - Returning #{final_results.size} items."
    puts "DEBUG [Context]: ------------------------------------------\n"
    final_results
  end

  private

  def search_query
    # Using the 5-word sniper logic we discussed
    @trend_name.gsub(/\.{2,}/, "")
               .gsub(/[[:punct:]]+$/, "")
               .split(/\s+/)
               .first(5)
               .join(" ")
  end

  def fetch_google_news(query)
    url = "https://news.google.com/rss/search?q=#{CGI.escape(query)}&hl=en-US&gl=US&ceid=US:en"
    puts "DEBUG [Google]: Requesting #{url}"
    parse_rss(url, source_prefix: "[News]")
  end

  def fetch_reddit_posts(query)
    url = "https://www.reddit.com/search.rss?q=#{CGI.escape(query)}&sort=relevance&t=day"
    puts "DEBUG [Reddit]: Requesting #{url}"
    headers = { "User-Agent" => USER_AGENT, "Accept" => "application/xml" }
    parse_rss(url, source_prefix: "[Reddit]", headers: headers)
  end

  def fetch_hacker_news(query)
    url = "https://hn.algolia.com/api/v1/search?query=#{CGI.escape(query)}&tags=story&hitsPerPage=10"
    puts "DEBUG [HN]: Requesting #{url}"

    begin
      # Opening with a block to capture the response metadata if needed
      response_raw = URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 5)
      data = JSON.parse(response_raw.read)

      puts "DEBUG [HN]: Algolia returned #{data['nbHits']} total matches."

      data["hits"].map do |hit|
        {
          headline: "[HN] #{hit['title']}".truncate(120),
          url: "https://news.ycombinator.com/item?id=#{hit['objectID']}",
          summary: "Points: #{hit['points']} | Comments: #{hit['num_comments']}"
        }
      end
    rescue => e
      puts "DEBUG [HN ERROR]: Type: #{e.class} | Message: #{e.message}"
      []
    end
  end

  def parse_rss(url, source_prefix:, headers: {})
  sanitizer = Rails::Html::FullSanitizer.new
  begin
    URI.open(url, headers.merge(read_timeout: 5)) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.map do |item|
        # 1. Clean the title
        clean_title = item.title.to_s.gsub(/<[^>]*>/, "").strip

        # 2. Extract Body
        raw_body = item.respond_to?(:description) ? item.description.to_s : ""

        # REDDIT SPECIAL: If it's a Reddit link, the 'description' often contains
        # a table with a thumbnail and a "submitted by" link.
        # We want to make sure we aren't just getting the "submitted by" text.
        clean_summary = sanitizer.sanitize(raw_body)
                                 .gsub(/submitted by.*/i, "") # Kill the user attribution
                                 .gsub(/\[link\].*|\[comments\].*/i, "") # Kill footer links
                                 .strip

        # Fallback: if summary is empty (image post), use the headline as the context
        final_summary = clean_summary.present? ? clean_summary : clean_title

        {
          headline: "#{source_prefix} #{clean_title}".truncate(120),
          url: item.link.to_s,
          summary: final_summary.truncate(500)
        }
      end
    end
  rescue => e
    puts "DEBUG [#{source_prefix} ERROR]: #{e.message}"
    []
  end
end
end
