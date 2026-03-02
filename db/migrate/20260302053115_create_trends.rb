class CreateTrends < ActiveRecord::Migration[8.0]
  def change
    create_table :trends do |t|
      t.string :name
      t.string :source
      t.integer :status

      t.timestamps
    end
    add_index :trends, :status
  end
end
