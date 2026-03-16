class AddReasoningToArticleAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_column :article_analyses, :reasoning, :text
  end
end
