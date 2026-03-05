# app/services/trend_context_service.rb
require "rss"
require "open-uri"

class TrendContextService
  USER_AGENT = "SentimentEngine/1.0 (RoR-#{rand(100)})"

  def self.call(trend_name)
    new(trend_name).call
  end

  def initialize(trend_name)
    # Don't escape here, escape in the URL generation to avoid double-escaping
    @trend_name = trend_name
  end

  def call
    puts "DEBUG [Context]: Starting fetch for '#{@trend_name}'"

    google = fetch_google_news
    puts "DEBUG [Context]: Found #{google.size} Google items"

    reddit = fetch_reddit_posts
    puts "DEBUG [Context]: Found #{reddit.size} Reddit items"

    google.first(3) + reddit.first(2)
  end

  private

  def fetch_google_news
    url = "https://news.google.com/rss/search?q=#{CGI.escape(@trend_name)}&hl=en-US&gl=US&ceid=US:en"
    parse_rss(url, source_prefix: "[News]")
  end

  def fetch_reddit_posts
    url = "https://www.reddit.com/search.rss?q=#{CGI.escape(@trend_name)}&sort=relevance&t=day"
    # Essential headers to avoid 429s
    headers = { "User-Agent" => USER_AGENT, "Accept" => "application/xml" }
    parse_rss(url, source_prefix: "[Reddit]", headers: headers)
  end

  def parse_rss(url, source_prefix:, headers: {})
    sanitizer = Rails::Html::FullSanitizer.new

    URI.open(url, headers) do |rss|
      feed = RSS::Parser.parse(rss)

      feed.items.map do |item|
        # 1. Title Safety (Atom vs RSS)
        clean_title = item.title.to_s.gsub(/<[^>]*>/, "").strip

        # 2. Body Safety (Atom uses .content or .summary, RSS uses .description)
        # We try content, then summary, then description, then fallback to empty string
        raw_body = if item.respond_to?(:content) && item.content
                     item.content.to_s
        elsif item.respond_to?(:summary) && item.summary
                     item.summary.to_s
        elsif item.respond_to?(:description)
                     item.description.to_s
        else
                     ""
        end

        puts "DEBUG [#{source_prefix}]: Got -> #{clean_title.truncate(50)}"

        {
          headline: "#{source_prefix} #{clean_title}".truncate(120),
          url: item.link.to_s,
          summary: sanitizer.sanitize(raw_body).truncate(500)
        }
      end
    end
  rescue => e
    puts "DEBUG [#{source_prefix} ERROR]: #{e.message}"
    Rails.logger.error "Context Fetcher Error (#{source_prefix}): #{e.message}"
    []
  end
end
