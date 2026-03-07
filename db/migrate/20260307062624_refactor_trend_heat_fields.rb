class RefactorTrendHeatFields < ActiveRecord::Migration[7.1]
  def change
    change_table :trends do |t|
      # Remove old ambiguous columns
      t.remove :bias_heat, :intensity_heat

      # Gemini Metrics
      t.float :gemini_avg_bias, default: 0.0
      t.float :gemini_avg_intensity, default: 0.0
      t.float :gemini_avg_score, default: 0.0

      # Grok Metrics
      t.float :grok_avg_bias, default: 0.0
      t.float :grok_avg_intensity, default: 0.0
      t.float :grok_avg_score, default: 0.0
    end
  end
end
