class AddUniqueIndexToArticleAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_index :article_analyses, [ :article_id, :llm_name ], unique: true
  end
end
