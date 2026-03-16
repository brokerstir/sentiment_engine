class AddDisagreementScoreToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :disagreement_score, :float
  end
end
