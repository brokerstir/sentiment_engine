require "net/http"
require "uri"
require "json"

class ArticleAnalyzerService
  def self.call(article)
    new(article).call
  end

  def initialize(article)
    @article = article
    @gemini_creds = Rails.application.credentials.gemini
    @grok_creds = Rails.application.credentials.grok
  end

  def call
    Rails.logger.info "--- Starting Analysis for Article ##{@article.id} ---"
    Rails.logger.info "Title: #{@article.title[0..50]}..."

    unless link_valid?
      Rails.logger.warn "  [ABORTED] Link is dead or invalid. Article ##{@article.id} destroyed."
      return
    end

    Rails.logger.info "  [SUCCESS] Link validated. Proceeding with LLM calls..."

    [ :gemini, :grok ].each do |llm|
      begin
        Rails.logger.info "  [RUNNING] Calling #{llm.to_s.upcase}..."

        response = send("post_to_#{llm}")

        if response.is_a?(Net::HTTPSuccess)
          parsed = parse_llm_response(response, llm)

          if parsed
            save_analysis(llm, parsed)
            Rails.logger.info "  [COMPLETED] #{llm.to_s.upcase} analysis saved (Bias: #{parsed['bias']}, Heat: #{parsed['heat']})."
          else
            Rails.logger.error "  [ERROR] #{llm.to_s.upcase} returned unparseable JSON."
          end
        else
          Rails.logger.error "  [ERROR] #{llm.to_s.upcase} API Failure: #{response.code} - #{response.message}"
        end

      rescue => e
        Rails.logger.error "  [CRASH] #{llm.to_s.upcase} failed for Article ##{@article.id}: #{e.message}"
      end
    end

    Rails.logger.info "--- Finished Analysis for Article ##{@article.id} ---"
  end

  private

  def link_valid?
    uri = URI.parse(@article.link)

    # 1. Setup Request
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5 # Don't wait forever
    http.read_timeout = 5

    # 2. Add a User-Agent (This is the "magic" fix)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    response = http.request(request)

    # 3. Check for success (2xx) or redirection (3xx)
    if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
      true
    else
      Rails.logger.warn "  [LINK CHECK] Failed for Article ##{@article.id}: HTTP #{response.code}"
      @article.destroy
      false
    end

  rescue SocketError => e
    Rails.logger.error "  [LINK CHECK] DNS/Connection Error for Article ##{@article.id}: #{e.message}"
    @article.destroy
    false
  rescue Timeout::Error
    Rails.logger.error "  [LINK CHECK] Timeout for Article ##{@article.id}. Skipping..."
    # Maybe don't destroy on a simple timeout?
    false
  rescue StandardError => e
    Rails.logger.error "  [LINK CHECK] Unexpected error for Article ##{@article.id}: #{e.class} - #{e.message}"
    @article.destroy
    false
  end

  def prompt_text
  <<~PROMPT
    Analyze this news article for sociopolitical framing.
    URL: #{@article.link}
    TITLE: #{@article.title}
    KEYWORDS: #{@article.keywords.join(", ")}

    SCORING DEFINITIONS:
    1. Bias Score (-1.0 to 1.0):#{' '}
       -1.0 = Far Left / Progressive / Anti-Establishment / Woke.
       1.0 = Far Right / Conservative / Nationalist / MAGA.
    2. Heat Score (0.0 to 1.0):#{' '}
       0.0 = Clinical, robotic, objective.
       1.0 = High emotional volatility, inflammatory, sensationalist.
    3. Evaluation Score (-1.0 to 1.0):#{' '}
       -1.0 = Scathing, critical of the article's subject.
       1.0 = Cheering, laudatory, supportive of the article's subject.

    TASK:
    - Summary: 3 succinct sentences.
    - Reasoning: 3 succinct sentences explaining why you gave these specific scores. Do no disclose the scores you gave in the reasoning.

    CRITICAL INSTRUCTION: Do not use special character. Do not stay 'neutral.' If the article has a lean, amplify your detection. Identify what is being intentionally omitted to shape the reader's opinion.

    Return ONLY valid JSON:
    {
      "bias": float,
      "heat": float,
      "evaluation": float,
      "summary": "string",
      "reasoning": "string"
    }
  PROMPT
end

  def post_to_gemini
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@gemini_creds[:model]}:generateContent?key=#{@gemini_creds[:api_key]}")
    payload = {
      contents: [ { parts: [ { text: "System: You are an expert sociopolitical linguist. #{prompt_text}" } ] } ]
    }
    make_request(uri, payload)
  end

  def post_to_grok
    uri = URI("https://api.x.ai/v1/chat/completions")
    payload = {
      model: @grok_creds[:model],
      messages: [
        { role: "system", content: "You are a senior sentiment analyst specialized in political bias. You output ONLY strictly valid JSON." },
        { role: "user", content: prompt_text }
      ]
    }
    make_request(uri, payload, "Bearer #{@grok_creds[:api_key]}")
  end

  def make_request(uri, payload, auth_header = nil)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request["Authorization"] = auth_header if auth_header
    request.body = payload.to_json
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
  end

  def parse_llm_response(response, llm)
    body = JSON.parse(response.body)
    raw_content = if llm == :gemini
      body.dig("candidates", 0, "content", "parts", 0, "text")
    else
      body.dig("choices", 0, "message", "content")
    end

    # Clean potential Markdown backticks from LLM output
    JSON.parse(raw_content.gsub(/```json|```/, ""))
  rescue => e
    Rails.logger.error "JSON Parsing Error for #{llm}: #{e.message}"
    nil
  end

  def save_analysis(llm, data)
    ArticleAnalysis.create!(
      article: @article,
      llm_name: llm.to_s,
      bias: data["bias"],
      heat: data["heat"],
      evaluation: data["evaluation"],
      summary: data["summary"],
      reasoning: data["reasoning"]
    )
  end
end
