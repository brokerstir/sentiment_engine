class CreateArticleAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :article_analyses do |t|
      t.references :article, null: false, foreign_key: true
      t.string :llm_name
      t.float :bias
      t.text :summary
      t.float :heat
      t.float :evaluation

      t.timestamps
    end
  end
end
