class AddIntensityToSentimentAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_column :sentiment_analyses, :intensity, :float
  end
end
