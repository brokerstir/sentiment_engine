# app/services/trend_context_service.rb
require "rss"
require "open-uri"
require "json"

class TrendContextService
  USER_AGENT = "SentimentEngine/1.0 (RoR-#{rand(100)})"

  def self.call(trend_name)
    new(trend_name).call
  end

  def initialize(trend_name)
    @trend_name = trend_name
  end

  def call
    puts "DEBUG [Context]: Starting fetch for '#{@trend_name}'"

    google = fetch_google_news
    reddit = fetch_reddit_posts
    hacker = fetch_hacker_news

    puts "DEBUG [Context]: G:#{google.size} | R:#{reddit.size} | HN:#{hacker.size}"

    # 1. Standard allocation for the "Golden 6"
    google_count = 2
    reddit_count = 1
    hacker_count = 3

    # 2. BLUNT FIX: If 0 Reddit found, give that slot to Google
    if reddit.empty?
      puts "DEBUG [Context]: 0 Reddit found. Increasing Google allocation."
      google_count += 1
      reddit_count = 0
    end

    # 3. Build the initial mix
    results = google.first(google_count) + reddit.first(reddit_count) + hacker.first(hacker_count)

    # 4. Final Fallback: If we are still under 6 (e.g., HN had 0 results)
    if results.size < 6
      puts "DEBUG [Context]: Results at #{results.size}/6. Filling remaining slots with Google News."
      existing_urls = results.map { |r| r[:url] }
      # Pull enough to hit 6 total
      remaining = google.reject { |g| existing_urls.include?(g[:url]) }.first(6 - results.size)
      results += remaining
    end

  puts "DEBUG [Context]: Final Mix Size: #{results.size}"
  results.first(6)
end

  private

  def fetch_google_news
    url = "https://news.google.com/rss/search?q=#{CGI.escape(@trend_name)}&hl=en-US&gl=US&ceid=US:en"
    parse_rss(url, source_prefix: "[News]")
  end

  def fetch_reddit_posts
    url = "https://www.reddit.com/r/worldnews/search.rss?q=#{CGI.escape(@trend_name)}&restrict_sr=on&sort=relevance&t=day"
    headers = { "User-Agent" => USER_AGENT, "Accept" => "application/xml" }
    parse_rss(url, source_prefix: "[Reddit]", headers: headers)
  end

  def fetch_hacker_news
    # Search stories, sorted by relevance/points. hitsPerPage=3 for buffer.
    url = "https://hn.algolia.com/api/v1/search?query=#{CGI.escape(@trend_name)}&tags=story&hitsPerPage=3"

    begin
      response = URI.open(url, "User-Agent" => USER_AGENT).read
      data = JSON.parse(response)

      data["hits"].map do |hit|
        {
          headline: "[HN] #{hit['title']}".truncate(120),
          url: "https://news.ycombinator.com/item?id=#{hit['objectID']}",
          # Algolia titles/urls don't usually have summaries, so we provide metadata
          summary: "HN Points: #{hit['points']} | Comments: #{hit['num_comments']}. " \
                   "Discussion link: https://news.ycombinator.com/item?id=#{hit['objectID']}"
        }
      end
    rescue => e
      puts "DEBUG [HN ERROR]: #{e.message}"
      []
    end
  end

  def parse_rss(url, source_prefix:, headers: {})
    sanitizer = Rails::Html::FullSanitizer.new

    URI.open(url, headers) do |rss|
      # IMPORTANT: false skips validation to prevent 'Missing Author' errors on Atom feeds
      feed = RSS::Parser.parse(rss, false)

      feed.items.map do |item|
        clean_title = item.title.to_s.gsub(/<[^>]*>/, "").strip

        raw_body = if item.respond_to?(:content) && item.content
                     item.content.to_s
        elsif item.respond_to?(:summary) && item.summary
                     item.summary.to_s
        elsif item.respond_to?(:description)
                     item.description.to_s
        else
                     ""
        end

        {
          headline: "#{source_prefix} #{clean_title}".truncate(120),
          url: item.link.to_s,
          summary: sanitizer.sanitize(raw_body).truncate(500)
        }
      end
    end
  rescue => e
    puts "DEBUG [#{source_prefix} ERROR]: #{e.message}"
    []
  end
end
