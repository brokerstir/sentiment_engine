class RemoveTrendIdFromSentimentAnalysis < ActiveRecord::Migration[8.0]
  def change
    remove_column :sentiment_analyses, :trend_id, :bigint
  end
end
