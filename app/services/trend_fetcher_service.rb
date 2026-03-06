class TrendFetcherService
  PROVIDERS = [
    Providers::GoogleTrendsProvider.new
    Providers::RedditTrendsProvider.new
    Providers::HackerNewsTrendsProvider.new
  ]

  # Practical limit for the lookup guard
  LOOKUP_LIMIT = 300

  def self.call
    new.call
  end

  def initialize
    # Senior Move: Load recent trend names into a Set for O(1) lookups
    # Pluck only the 'name' column to keep the memory footprint tiny
    @recent_trend_names = Trend.order(created_at: :desc)
                               .limit(LOOKUP_LIMIT)
                               .pluck(:name)
                               .to_set
  end

  def call
    PROVIDERS.each do |provider|
      provider.fetch.each do |data|
        # 1. Guard clause: Skip if it's in our recent lookup Set
        next if @recent_trend_names.include?(data[:name])

        # 2. Persistence: find_or_create_by! handles the 1% edge case
        # (e.g., race conditions or trends older than 300 records)
        Trend.find_or_create_by!(name: data[:name]) do |t|
          t.source = data[:source]
          t.status = :pending
        end

        # 3. Optimization: Add new name to the set so we don't
        # process duplicates from multiple providers in the same run
        @recent_trend_names << data[:name]
      end
    end
  end
end
