class TrendFetcherService
  def self.call
    new.call
  end

  def call
    # Mock data for now; we'll plug in real APIs in Phase 3
    mock_trends = [
      { name: "#Rails8", source: "X" },
      { name: "TursoDB", source: "X" },
      { name: "Apple M4 Mac", source: "Google" }
    ]

    mock_trends.map do |data|
      Trend.find_or_create_by!(name: data[:name]) do |t|
        t.source = data[:source]
        t.status = :pending
      end
    end
  end
end