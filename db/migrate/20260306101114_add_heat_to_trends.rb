class AddHeatToTrends < ActiveRecord::Migration[8.0]
  def change
    add_column :trends, :bias_heat, :float
    add_column :trends, :intensity_heat, :float
  end
end
