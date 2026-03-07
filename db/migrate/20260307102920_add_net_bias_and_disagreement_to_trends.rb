class AddNetBiasAndDisagreementToTrends < ActiveRecord::Migration[7.1]
  def change
    change_table :trends do |t|
      # Directional averages (Unsigned/Raw)
      t.float :gemini_net_bias, default: 0.0
      t.float :grok_net_bias, default: 0.0

      # The "Sticky" Signal (Delta between Gemini and Grok)
      t.float :bias_disagreement, default: 0.0
    end
  end
end
