class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :link
      t.json :keywords
      t.json :category
      t.datetime :pub_date

      t.timestamps
    end
  end
end
