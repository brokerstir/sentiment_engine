class AddSourceItemToSentimentAnalysis < ActiveRecord::Migration[8.0]
  def change
    add_reference :sentiment_analyses, :source_item, null: false, foreign_key: true
  end
end
