require "net/http"
require "json"

class SentimentAnalyzerService
  def self.call(trend)
    # Senior Guard: See which models have already analyzed this trend
    existing_models = trend.sentiment_analyses.pluck(:llm_model).to_set

    # Only pick providers that haven't run yet
    providers_to_run = [:gemini, :grok].reject do |p|
      existing_models.include?(Rails.application.credentials.dig(p, :model))
    end

    if providers_to_run.empty?
      puts "SKIPPING: Trend '#{trend.name}' already analyzed by all models."
      return
    end

    # Fetch context only if we actually have work to do
    context = TrendContextService.call(trend.name)
    puts "Context fetched: #{context.truncate(50)}"

    providers_to_run.each do |provider|
      new(trend, provider, context).call
    end

    trend.completed!
  end

  def initialize(trend, provider_name, context)
    @trend = trend
    @provider_name = provider_name
    @creds = Rails.application.credentials[provider_name]
    @context = context
  end

  def call
    # Final safety check: Double-check inside the instance call
    # to prevent race conditions if multiple workers hit this at once.
    if @trend.sentiment_analyses.exists?(llm_model: @creds[:model])
      puts "SKIPPING [#{@provider_name}]: Model '#{@creds[:model]}' already exists for this trend."
      return
    end

    result = fetch_analysis
    if result.nil?
      puts "FAILED: No result returned from #{@provider_name}"
      return
    end

    # Senior Practice: use create! (with bang) to raise error if validation fails
    analysis = @trend.sentiment_analyses.create!(
      llm_model: @creds[:model],
      score: result["score"],
      intensity: result["intensity"],
      reasoning: result["reasoning"]
    )
    puts "SUCCESS: Created analysis for #{@provider_name} (ID: #{analysis.id})"
  rescue => e
    puts "CRITICAL ERROR [#{@provider_name}]: #{e.message}"
    Rails.logger.error "[SentimentAnalyzerService] #{e.message}"
  end

  private

  def fetch_analysis
    response = (@provider_name == :gemini) ? post_to_gemini : post_to_grok

    unless response.is_a?(Net::HTTPSuccess)
      puts "HTTP ERROR [#{@provider_name}]: #{response.code} - #{response.body}"
      return nil
    end

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

  def post_to_gemini
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@creds[:model]}:generateContent?key=#{@creds[:api_key]}")
    payload = { contents: [{ parts: [{ text: prompt_text }] }] }
    make_request(uri, payload)
  end

  def post_to_grok
    # Ensure this URL matches the latest xAI documentation
    uri = URI("https://api.x.ai/v1/chat/completions")
    payload = {
      model: @creds[:model],
      messages: [
        { role: "system", content: "You are a sentiment analyst. Output ONLY JSON." },
        { role: "user", content: prompt_text }
      ]
    }
    make_request(uri, payload, "Bearer #{@creds[:api_key]}")
  end

  def make_request(uri, payload, auth_header = nil)
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request["Authorization"] = auth_header if auth_header
    request.body = payload.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def prompt_text
    "Analyze sentiment for '#{@trend.name}' given this context: '#{@context}'. " \
    "Return JSON: { \"score\": float (-1 to 1), \"intensity\": float (0 to 1), \"reasoning\": \"string\" }"
  end
end
