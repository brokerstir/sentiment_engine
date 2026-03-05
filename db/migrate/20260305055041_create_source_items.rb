class CreateSourceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :source_items do |t|
      t.references :trend, null: false, foreign_key: true
      t.string :headline
      t.string :url

      t.timestamps
    end
  end
end
