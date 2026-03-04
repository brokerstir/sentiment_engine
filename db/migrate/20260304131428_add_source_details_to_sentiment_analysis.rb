class AddSourceDetailsToSentimentAnalysis < ActiveRecord::Migration[8.0]
  def change
    add_column :sentiment_analyses, :headline, :string
    add_column :sentiment_analyses, :url, :string
  end
end
