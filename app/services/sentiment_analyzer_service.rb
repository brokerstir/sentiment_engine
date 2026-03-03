class SentimentAnalyzerService
  def initialize(trend)
    @trend = trend
  end

  def call
    # 1. Define your prompt to force JSON output
    prompt = "Analyze the sentiment for the topic: '#{@trend.name}'. 
              Return ONLY a JSON object with: 
              { 'score': float (-1.0 to 1.0), 'reasoning': 'text', 'tone': 'string' }"

    # 2. Logic to pick which AI to use (we can cycle through them)
    # For now, let's use a placeholder for your chosen model
    response_data = fetch_ai_analysis(prompt)

    # 3. Save the result
    @trend.sentiment_analyses.create!(
      llm_model: "PLACEHOLDER_MODEL_NAME", # e.g., claude-3-5-sonnet
      score: response_data[:score],
      reasoning: response_data[:reasoning]
    )

    @trend.completed!
  end

  private

  def fetch_ai_analysis(prompt)
    # This is where we will put the specific API calls for Gemini/Anthropic/Grok
    # For today's test, we return mock data to ensure the pipeline is solid.
    { score: 0.85, reasoning: "Strong positive outlook on Rails 8 features.", tone: "Excited" }
  end
end