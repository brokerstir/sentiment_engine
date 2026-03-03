class TrendFetcherService
  # Add more providers here as we get API keys (e.g., XProvider.new)
  PROVIDERS = [
    Providers::GoogleTrendsProvider.new
  ]

  def self.call
    new.call
  end

  def call
    PROVIDERS.each do |provider|
      provider.fetch.each do |data|
        Trend.find_or_create_by!(name: data[:name]) do |t|
          t.source = data[:source]
          t.status = :pending
        end
      end
    end
  end
end
