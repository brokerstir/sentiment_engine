# app/services/trend_fetcher_service.rb
class TrendFetcherService
  # Key-Value mapping to tag the origin
  PROVIDERS = {
    google: Providers::GoogleTrendsProvider.new
    # reddit: Providers::RedditTrendsProvider.new
    # hacker_news: Providers::HackerNewsTrendsProvider.new
  }

  LOOKUP_LIMIT = 300

  def self.call
    new.call
  end

  def initialize
    @recent_trend_names = Trend.order(created_at: :desc)
                               .limit(LOOKUP_LIMIT)
                               .pluck(:name)
                               .to_set
  end

  def call
    PROVIDERS.each do |key, provider|
      provider.fetch.each do |data|
        next if @recent_trend_names.include?(data[:name])

        Trend.find_or_create_by!(name: data[:name]) do |t|
          t.source = data[:source]
          t.source_provider = key.to_s # Store 'google', 'reddit', or 'hacker_news'
          t.status = :pending
        end

        @recent_trend_names << data[:name]
      end
    end
  end
end
