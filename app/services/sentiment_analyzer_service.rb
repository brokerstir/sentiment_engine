require "net/http"
require "json"

class SentimentAnalyzerService
  def self.call(trend)
    context_items = TrendContextService.call(trend.name)
    expected_count = context_items.size

    [ :gemini, :grok ].each do |provider|
      model_name = Rails.application.credentials.dig(provider, :model)

      # Senior Fix: Only skip if the record count matches the context count
      actual_count = trend.sentiment_analyses.where(llm_model: model_name).count

      if actual_count >= expected_count
        puts "SKIPPING [#{provider}]: All #{expected_count} items analyzed."
        next
      end

      new(trend, provider, context_items).call
    end

    trend.completed!
  end

  def initialize(trend, provider_name, context_items)
    @trend = trend
    @provider_name = provider_name
    @creds = Rails.application.credentials[provider_name]
    @context_items = context_items
  end

  def call
    @context_items.each_with_index do |item_context, index|
      # Deep Guard: Don't re-analyze the specific index if it exists
      # Note: This assumes order is consistent (it is, from the RSS feed)
      if @trend.sentiment_analyses.where(llm_model: @creds[:model]).offset(index).exists?
        next
      end

      result = fetch_analysis(item_context)

      if result
        @trend.sentiment_analyses.create!(
          llm_model: @creds[:model],
          score: result["score"],
          intensity: result["intensity"],
          reasoning: result["reasoning"]
        )
        puts "SUCCESS [#{@provider_name}]: Created analysis for item #{index + 1}"
      end
    end
  rescue => e
    puts "CRITICAL ERROR [#{@provider_name}]: #{e.message}"
  end

  private

  def fetch_analysis(specific_context)
    response = (@provider_name == :gemini) ? post_to_gemini(specific_context) : post_to_grok(specific_context)

    return nil unless response.is_a?(Net::HTTPSuccess)
    parse_ai_response(response)
  end

  def parse_ai_response(response)
    body = JSON.parse(response.body)

    # Correct key paths for the specific APIs
    raw_text = if @provider_name == :gemini
                 body.dig("candidates", 0, "content", "parts", 0, "text")
    else
                 # Grok/OpenAI format usually uses choices -> message -> content
                 body.dig("choices", 0, "message", "content")
    end

    return nil if raw_text.blank?

    # Robust JSON extraction
    json_match = raw_text.match(/\{.*\}/m)
    json_match ? JSON.parse(json_match[0]) : nil
  end

  def post_to_gemini(specific_context)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@creds[:model]}:generateContent?key=#{@creds[:api_key]}")
    payload = { contents: [ { parts: [ { text: prompt_text(specific_context) } ] } ] }
    make_request(uri, payload)
  end

  def post_to_grok(specific_context)
    uri = URI("https://api.x.ai/v1/chat/completions")
    payload = {
      model: @creds[:model],
      messages: [
        { role: "system", content: "You are a sentiment analyst. Output ONLY JSON." },
        { role: "user", content: prompt_text(specific_context) }
      ]
    }
    make_request(uri, payload, "Bearer #{@creds[:api_key]}")
  end

  def make_request(uri, payload, auth_header = nil)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request["Authorization"] = auth_header if auth_header
    request.body = payload.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def prompt_text(specific_context)
    "Analyze sentiment for '#{@trend.name}' based ONLY on this specific news item: '#{specific_context}'. " \
    "Return JSON: { \"score\": float (-1 to 1), \"intensity\": float (0 to 1), \"reasoning\": \"string\" }"
  end
end
