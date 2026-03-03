class TrendContextService
  def self.call(trend_name)
    new(trend_name).call
  end

  def initialize(trend_name)
    @trend_name = trend_name
  end

  def call
    # For now, we'll simulate the search results.
    # In Phase 4, we'll plug in the NewsAPI key here.
    [
      "Latest update on #{@trend_name} injury report.",
      "#{@trend_name} trade rumors heating up ahead of deadline.",
      "Fan reaction to #{@trend_name} recent performance."
    ].join(" | ")
  end
end
