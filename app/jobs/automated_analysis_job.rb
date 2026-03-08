class AutomatedAnalysisJob < ApplicationJob
  queue_as :default

  def perform
    puts "--- [BATTLE LOG] STARTING AUTOMATED SWEEP ---"

    # Stage 1: Equivalent to your 'fetcht' alias
    TrendFetcherService.call
    puts "DEBUG: Fetcher cycle complete."

    # Stage 2: Equivalent to your 'runsa' alias
    # We sweep everything marked :pending by the fetcher
    Trend.pending.each do |trend|
      puts "DEBUG: Analyzing: #{trend.name}"
      SentimentAnalyzerService.call(trend)
    rescue => e
      puts "ERROR on Trend #{trend.id}: #{e.message}"
      trend.update(status: :failed)
    end

    puts "--- [BATTLE LOG] SWEEP COMPLETE ---"
  end
end
