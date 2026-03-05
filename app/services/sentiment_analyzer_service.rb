require "net/http"
require "json"

class SentimentAnalyzerService
  def self.call(trend)
    puts "\n[SYSTEM] >>> Starting Trend: #{trend.name} (ID: #{trend.id})"

    # Check if the trend actually exists in DB
    unless Trend.exists?(trend.id)
      puts "[SYSTEM] ERROR: Trend object passed to Service does not exist in DB!"
      return
    end

    context_items = TrendContextService.call(trend.name)
    if context_items.empty?
      puts "[SYSTEM] WARN: No news items found."
      return
    end

    [:gemini, :grok].each do |provider|
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
    # DEBUG: Inspect the models at runtime to see what Rails REALLY thinks
    puts "DEBUG [#{@provider_name}]: SentimentAnalysis Associations: #{SentimentAnalysis.reflect_on_all_associations.map(&:name)}"
    puts "DEBUG [#{@provider_name}]: SourceItem Associations: #{SourceItem.reflect_on_all_associations.map(&:name)}"

    analyzed_ids = @trend.sentiment_analyses
                         .where(llm_model: @creds[:model])
                         .pluck(:source_item_id).to_set

    @context_items.each_with_index do |item, idx|
      puts "DEBUG [#{@provider_name}]: Processing item #{idx + 1}/#{@context_items.size}"

      # 1. Surgical SourceItem Check
      source_item = nil
      begin
        source_item = SourceItem.find_or_create_by!(url: item[:url], trend_id: @trend.id) do |si|
          si.headline = item[:headline]
        end
        puts "DEBUG [#{@provider_name}]: SourceItem ID: #{source_item.id} (Trend ID check: #{source_item.trend_id})"
      rescue => e
        puts "CRITICAL ERROR [#{@provider_name}] at SourceItem: #{e.message}"
        next
      end

      next if analyzed_ids.include?(source_item.id)

      # 2. AI Call
      result = fetch_analysis(item[:summary])

      if result
        begin
          # 3. Surgical SentimentAnalysis Save
          # We create the object first so we can inspect it before saving
          analysis = SentimentAnalysis.new(
            source_item_id: source_item.id,
            llm_model: @creds[:model],
            score: result["score"],
            intensity: result["intensity"],
            reasoning: result["reasoning"]
          )

          puts "DEBUG [#{@provider_name}]: Analysis Object Ready. valid? #{analysis.valid?}"
          unless analysis.valid?
            puts "DEBUG [#{@provider_name}]: Validation Errors: #{analysis.errors.full_messages}"
          end

          analysis.save!
          puts "SUCCESS [#{@provider_name}]: Created Analysis ID #{analysis.id}"
        rescue => e
          puts "CRITICAL ERROR [#{@provider_name}] at SentimentAnalysis: #{e.message}"
          # If save! fails but valid? was true, something hidden is happening (callbacks, DB constraints)
        end
      end
    end
  end

  private

  def fetch_analysis(text)
    response = (@provider_name == :gemini) ? post_to_gemini(text) : post_to_grok(text)
    return nil unless response.is_a?(Net::HTTPSuccess)
    parse_ai_response(response)
  end

  def post_to_gemini(text)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@creds[:model]}:generateContent?key=#{@creds[:api_key]}")
    payload = { contents: [ { parts: [ { text: prompt_text(text) } ] } ] }
    make_request(uri, payload)
  end

  def post_to_grok(text)
    uri = URI("https://api.x.ai/v1/chat/completions")
    payload = {
      model: @creds[:model],
      messages: [
        { role: "system", content: "You are a sentiment analyst. Output ONLY JSON." },
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
    json_match ? JSON.parse(json_match[0]) : nil
  end

  def prompt_text(text)
    "Analyze sentiment for '#{@trend.name}' based on: '#{text}'. " \
    "Return JSON: { \"score\": float, \"intensity\": float, \"reasoning\": \"string\" }"
  end
end