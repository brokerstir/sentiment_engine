class AddBiasToSentimentAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_column :sentiment_analyses, :bias, :float
  end
end
