class CreateSentimentAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :sentiment_analyses do |t|
      t.references :trend, null: false, foreign_key: true
      t.string :llm_model
      t.float :score
      t.text :reasoning

      t.timestamps
    end
  end
end
