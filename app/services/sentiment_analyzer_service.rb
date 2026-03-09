require "net/http"
require "json"

class SentimentAnalyzerService
  def self.call(trend)
    puts "\n[SYSTEM] >>> Starting Trend: #{trend.name} (ID: #{trend.id} | Source: #{trend.source_provider})"

    unless Trend.exists?(trend.id)
      puts "[SYSTEM] ERROR: Trend #{trend.id} not found in DB."
      return
    end

    context_items = TrendContextService.call(trend)

    if context_items.empty?
      puts "[SYSTEM] WARN: TrendContextService returned 0 items for '#{trend.name}'"
      trend.failed! # No context means no heat, mark as failed to clear the queue
      return
    end

    # 1. Run Analysis for both providers
    [ :gemini, :grok ].each do |provider|
      new(trend, provider, context_items).call
    end

    # 2. Trigger the Heat Guard
    if passes_heat_guard?(trend)
      trend.completed!
      puts "[SYSTEM] >>> Trend #{trend.id} PASSED Heat Guard (Completed)."
    else
      trend.failed!
      puts "[SYSTEM] >>> Trend #{trend.id} FAILED Heat Guard (Marked Failed)."
    end
  end

  def self.passes_heat_guard?(trend)
    # RELOAD is critical here. Without it, Rails might see an empty collection
    # because the trend object was loaded BEFORE the analyses were created.
    analyses = trend.sentiment_analyses.reload

    if analyses.empty?
      puts "DEBUG [HeatGuard]: REJECTED - No analyses found for Trend ID: #{trend.id}"
      return false
    end

    puts "DEBUG [HeatGuard]: --- Calculating Heat for '#{trend.name}' ---"

    # We split the data into two distinct buckets
    grouped = analyses.group_by(&:llm_model)

    # Initialize placeholders for the averages
    # We will store them in a hash for easy comparison later
    stats = { gemini: {}, grok: {} }

    grouped.each do |model_name, data|
      # Determine if this bucket belongs to Gemini or Grok
      provider_key = model_name.downcase.include?("gemini") ? :gemini : :grok

      # 1. BIAS AVERAGE (The "Juice"): We use Absolute Values so opposites don't cancel out
      avg_bias = data.map { |a| a.bias.to_f.abs }.sum / data.size

      # 2. NET BIAS (Directional): Raw averages to see the actual lean (-1 to 1)
      net_bias = data.map { |a| a.bias.to_f }.sum / data.size

      # 3. INTENSITY AVERAGE: Measuring the raw emotional heat
      avg_intensity = data.map { |a| a.intensity.to_f }.sum / data.size

      # 4. SCORE AVERAGE: Measuring the general sentiment (Positive vs Negative)
      avg_score = data.map { |a| a.score.to_f }.sum / data.size

      # Store results for this specific provider
      stats[provider_key] = {
        bias: avg_bias,
        net_bias: net_bias,
        intensity: avg_intensity,
        score: avg_score,
        count: data.size
      }

      # CLEAR LOGGING: Distinctly labeling Grok vs Gemini averages
      label = provider_key.to_s.upcase
      puts "DEBUG [HeatGuard]: #{label} AVERAGES -> " \
           "Bias Heat: #{avg_bias.round(4)} | " \
           "Net Lean: #{net_bias.round(4)} | " \
           "Intensity: #{avg_intensity.round(4)} | " \
           "Score: #{avg_score.round(4)} | " \
           "Samples: #{data.size}"
    end

    # --- CALCULATE DISAGREEMENT (Consensus Spread) ---
    g_net = stats.dig(:gemini, :net_bias) || 0.0
    x_net = stats.dig(:grok, :net_bias) || 0.0
    disagreement = (g_net - x_net).abs

    # PERSISTENCE: Mapping the stats hash directly to the updated Trend columns
    trend.update(
      gemini_avg_bias:      stats.dig(:gemini, :bias) || 0.0,
      gemini_net_bias:      g_net,
      gemini_avg_intensity: stats.dig(:gemini, :intensity) || 0.0,
      gemini_avg_score:     stats.dig(:gemini, :score) || 0.0,

      grok_avg_bias:        stats.dig(:grok, :bias) || 0.0,
      grok_net_bias:        x_net,
      grok_avg_intensity:   stats.dig(:grok, :intensity) || 0.0,
      grok_avg_score:       stats.dig(:grok, :score) || 0.0,

      bias_disagreement:    disagreement
    )

    # Simplified Debug Log for the new structure
    puts "DEBUG [HeatGuard]: Trend #{trend.id} updated with dual-provider averages."
    puts "DEBUG [HeatGuard]: Gemini -> B: #{trend.gemini_avg_bias.round(3)} | Net: #{trend.gemini_net_bias.round(3)}"
    puts "DEBUG [HeatGuard]: Grok   -> B: #{trend.grok_avg_bias.round(3)}   | Net: #{trend.grok_net_bias.round(3)}"
    puts "DEBUG [HeatGuard]: Consensus Disagreement: #{trend.bias_disagreement.round(4)}"

    true
  end

  def initialize(trend, provider_name, context_items)
    @trend = trend
    @provider_name = provider_name
    @context_items = context_items
    @creds = Rails.application.credentials[provider_name]
    raise "Missing credentials for #{provider_name}" if @creds.nil?
  end

  # app/services/sentiment_analyzer_service.rb

  def call
    puts "DEBUG [#{@provider_name}]: Goal: #{@context_items.size} analyses for Trend #{@trend.id}"

    analyzed_ids = @trend.sentiment_analyses
                         .where(llm_model: @creds[:model])
                         .pluck(:source_item_id).to_set

    @context_items.each do |item|
      # 1. Ensure the SourceItem exists so we can attach analyses to it
      source_item = SourceItem.find_or_create_by!(url: item[:url], trend_id: @trend.id) do |si|
        si.headline = item[:headline]
      end

      # 2. Skip if this specific LLM has already analyzed this specific Item
      if analyzed_ids.include?(source_item.id)
        puts "DEBUG [#{@provider_name}]: SKIP - Item #{source_item.id} already analyzed."
        next
      end

      # 3. Log the Payload for every iteration
      puts "DEBUG [#{@provider_name} Payload]: Sending to AI -> \"#{item[:summary].to_s.gsub("\n", " ").truncate(100)}\""

      # 4. Throttling and API Call
      sleep(1)
      result = fetch_analysis(item[:summary])

      # 5. RESTORED: Persistence Logic
      if result
        begin
          analysis = SentimentAnalysis.create!(
            source_item_id: source_item.id,
            llm_model: @creds[:model],
            score: result["score"],
            intensity: result["intensity"],
            bias: result["bias"],
            reasoning: result["reasoning"]
          )
          puts "SUCCESS [#{@provider_name}]: Created Analysis ID #{analysis.id} (Bias: #{analysis.bias})"
        rescue => e
          puts "CRITICAL ERROR [#{@provider_name}]: Save failed: #{e.message}"
        end
      else
        puts "WARN [#{@provider_name}]: fetch_analysis returned nil. Skipping save."
      end
    end
  end

  def self.run_drip
    trend = Trend.pending.order(created_at: :asc).first
    return puts "[DRIP] No pending trends found." unless trend

    puts "[DRIP] Processing oldest pending: #{trend.name} (ID: #{trend.id})"
    call(trend)
  end

  private

  def fetch_analysis(text)
    response = (@provider_name == :gemini) ? post_to_gemini(text) : post_to_grok(text)

    unless response.is_a?(Net::HTTPSuccess)
      puts "DEBUG [#{@provider_name}]: API ERROR -> Code: #{response.code}"
      return nil
    end

    result = parse_ai_response(response)

    # SUCCESS LOG: Individual Sentiment Analysis (SA) results
    if result
      puts "DEBUG [#{@provider_name}]: RAW SA -> Score: #{result['score'].to_s.ljust(5)} | " \
           "Bias: #{result['bias'].to_s.ljust(5)} | " \
           "Intensity: #{result['intensity']}"
    end

    result
  end

  def post_to_gemini(text)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@creds[:model]}:generateContent?key=#{@creds[:api_key]}")
    payload = {
      contents: [ { parts: [ { text: "System: You are a linguist trained in detecting political bias and emotional intensity. #{prompt_text(text)}" } ] } ]
    }
    make_request(uri, payload)
  end

  def post_to_grok(text)
    uri = URI("https://api.x.ai/v1/chat/completions")
    payload = {
      model: @creds[:model],
      messages: [
        { role: "system", content: "You are a senior sentiment analyst specialized in political bias and emotional intensity. You output ONLY strictly valid JSON." },
        { role: "user", content: prompt_text(text) }
      ]
    }
    make_request(uri, payload, "Bearer #{@creds[:api_key]}")
  end

  def make_request(uri, payload, auth_header = nil)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request["Authorization"] = auth_header if auth_header
    request.body = payload.to_json
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
  end

  def parse_ai_response(response)
    body = JSON.parse(response.body)
    raw_text = (@provider_name == :gemini) ?
      body.dig("candidates", 0, "content", "parts", 0, "text") :
      body.dig("choices", 0, "message", "content")

    return nil if raw_text.blank?

    json_match = raw_text.match(/\{.*\}/m)
    if json_match
      begin
        JSON.parse(json_match[0])
      rescue JSON::ParserError
        nil
      end
    end
  end

  def prompt_text(text)
    <<~PROMPT
      You are an expert sentiment and political analyst. Analyze the following text in relation to the trend: "#{@trend.name}".

      TEXT TO ANALYZE: "#{text}"

      CRITERIA:
      1. Score (-1.0 to 1.0): Negative/Criticism vs. Positive/Praise.
      2. Intensity (0.0 to 1.0): Emotional heat, passion, or urgency.
      3. Bias (-1.0 to 1.0): Political alignment (-1.0: Anti-Establishment/Left, 0.0: Neutral, 1.0: Pro-Establishment/Right).
      4. Reasoning (Holistic): Synthesize how the language, tone, and perspective justify the scores above.

      OUTPUT INSTRUCTIONS:
      Return ONLY valid JSON. Constraint: "reasoning" must be 2-3 concise sentences (max 120 words).
      Format: { "score": float, "intensity": float, "bias": float, "reasoning": "string" }
    PROMPT
  end
end
