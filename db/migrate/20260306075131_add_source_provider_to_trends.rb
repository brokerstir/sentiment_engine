class AddSourceProviderToTrends < ActiveRecord::Migration[8.0]
  def change
    add_column :trends, :source_provider, :string
  end
end
