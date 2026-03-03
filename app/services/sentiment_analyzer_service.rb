require "net/http"
require "json"

class SentimentAnalyzerService
  def self.call(trend)
    new(trend).call
  end

  def initialize(trend)
    @trend = trend
    @creds = Rails.application.credentials.gemini

    # This is exactly what you showed works in the console
    @api_key = @creds.api_key
    @model = @creds.model
  end

  def call
    context = TrendContextService.call(@trend.name)

    # We keep your exact prompt
    prompt = <<~PROMPT
      Analyze the sentiment of the following news context for the topic "#{@trend.name}":
      "#{context}"

      Return ONLY a JSON object with:
      {
        "score": float (-1.0 to 1.0, where -1 is very negative/hateful, 1 is very positive/joyful),
        "intensity": float (0.0 to 1.0, where 0 is boring/indifferent, 1 is high-passion/viral/angry/excited),
        "reasoning": "A concise 2-sentence explanation"
      }
    PROMPT

    # We replace the broken @client.generate_content with a direct API call
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{@api_key}")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request.body = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    # Extract JSON from the raw response body
    raw_body = JSON.parse(response.body)
    raw_text = raw_body.dig("candidates", 0, "content", "parts", 0, "text")

    # Your preferred JSON extraction logic
    clean_json = raw_text.match(/\{.*\}/m)[0]
    result = JSON.parse(clean_json)

    # Save to DB using your schema
    @trend.sentiment_analyses.create!(
      llm_model: @model,
      score: result["score"],
      intensity: result["intensity"],
      reasoning: result["reasoning"]
    )

    @trend.completed!
  rescue => e
    @trend.failed!
    Rails.logger.error "[SentimentAnalyzerService] Error: #{e.message}"
    raise e
  end
end