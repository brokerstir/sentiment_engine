require "net/http"
require "json"

class SentimentAnalyzerService
  def self.call(trend)
    puts "\n[SYSTEM] >>> Starting Trend: #{trend.name} (ID: #{trend.id} | Source: #{trend.source_provider})"

    unless Trend.exists?(trend.id)
      puts "[SYSTEM] ERROR: Trend #{trend.id} not found in DB."
      return
    end

    # PASSING THE TREND OBJECT: This triggers the Isolated Strategy (G, R, or HN)
    context_items = TrendContextService.call(trend)

    if context_items.empty?
      puts "[SYSTEM] WARN: TrendContextService returned 0 items for '#{trend.name}'"
      # We mark as completed even if empty so it doesn't get stuck in the 'pending' loop
      trend.completed!
      return
    end

    [ :gemini, :grok ].each do |provider|
      new(trend, provider, context_items).call
    end

    trend.completed!
    puts "[SYSTEM] >>> Trend #{trend.id} COMPLETED.\n"
  end

  def initialize(trend, provider_name, context_items)
    @trend = trend
    @provider_name = provider_name
    @context_items = context_items
    @creds = Rails.application.credentials[provider_name]
    raise "Missing credentials for #{provider_name}" if @creds.nil?
  end

  def call
    puts "DEBUG [#{@provider_name}]: Goal: #{@context_items.size} analyses for Trend #{@trend.id}"

    analyzed_ids = @trend.sentiment_analyses
                         .where(llm_model: @creds[:model])
                         .pluck(:source_item_id).to_set

    @context_items.each_with_index do |item, idx|
      # find_or_create_by! ensures we don't duplicate context across Gemini/Grok runs
      source_item = SourceItem.find_or_create_by!(url: item[:url], trend_id: @trend.id) do |si|
        si.headline = item[:headline]
      end

      if analyzed_ids.include?(source_item.id)
        puts "DEBUG [#{@provider_name}]: SKIP - Already analyzed Item #{source_item.id}"
        next
      end

      # The LLM analysis call
      result = fetch_analysis(item[:summary])

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
      puts "DEBUG [#{@provider_name}]: HTTP ERROR - Code: #{response.code} | Body: #{response.body.truncate(100)}"
      return nil
    end

    parse_ai_response(response)
  end

  def post_to_gemini(text)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@creds[:model]}:generateContent?key=#{@creds[:api_key]}")

    payload = {
      contents: [
        {
          parts: [
            { text: "System: You are a linguist trained in detecting political bias and emotional intensity. #{prompt_text(text)}" }
          ]
        }
      ]
    }
    make_request(uri, payload)
  end

  def post_to_grok(text)
    uri = URI("https://api.x.ai/v1/chat/completions")
    payload = {
      model: @creds[:model],
      messages: [
        {
          role: "system",
          content: "You are a senior sentiment analyst specialized in political bias and emotional intensity. You output ONLY strictly valid JSON."
        },
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
      3. Bias (-1.0 to 1.0): Perspective alignment (-1.0: Anti-Establishment/Left, 0.0: Neutral, 1.0: Pro-Establishment/Right).
      4. Reasoning (Holistic): Synthesize how the language, tone, and perspective justify the scores above.

      OUTPUT INSTRUCTIONS:
      Return ONLY valid JSON. Constraint: "reasoning" must be 2-3 concise sentences (max 120 words).
      Format: { "score": float, "intensity": float, "bias": float, "reasoning": "string" }
    PROMPT
  end
end
