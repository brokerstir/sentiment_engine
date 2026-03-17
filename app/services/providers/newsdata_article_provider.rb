require "httparty"

module Providers
  class NewsdataArticleProvider
    include HTTParty
    base_uri "https://newsdata.io/api/1"

    CATEGORIES = %w[world politics domestic crime health science].freeze

    def initialize
      @api_key = Rails.application.credentials.dig(:newsdata, :api_key)
      if @api_key.blank?
        Rails.logger.error "[CONFIG ERROR] NewsData API Key is missing from credentials!"
      else
        Rails.logger.info "[CONFIG] NewsData API Key loaded successfully."
      end
    end

    def fetch
      saved_articles = []

      return [] if @api_key.blank? && Rails.logger.error("Aborting fetch: No API Key.")

      Rails.logger.info "--- Starting NewsData Fetch Cycle ---"

      # --- CRITICAL FIX: MOVE GUARDS OUTSIDE THE LOOP ---
      # Query the DB ONCE for the entire fetch cycle, not once per category.
      lookback_date = 5.days.ago
      existing_links = Article.where("pub_date >= ?", lookback_date).pluck(:link).to_set
      existing_titles = Article.where("pub_date >= ?", lookback_date).pluck(:title).to_set
      # --------------------------------------------------

      CATEGORIES.each do |category|
        Rails.logger.info "[REQ] Category: #{category}..."

        response = self.class.get("/latest", query: {
          apikey: @api_key,
          category: category,
          language: "en",
          size: 7
        })

        if response.success?
          articles_data = response.parsed_response["results"] || []
          Rails.logger.info "  [SUCCESS] Found #{articles_data.size} articles." unless articles_data.empty?

          articles_data.each do |data|
            # Skip if link or title exists (Double Guard)
            if existing_links.include?(data["link"]) || existing_titles.include?(data["title"])
              # Only log skips if you're debugging; otherwise, it clogs logs
              next
            end

            article = Article.new(link: data["link"])

            begin
              # Use public_send or check if data['pubDate'] needs parsing
              article.update!(
                title: data["title"],
                keywords: data["keywords"] || [],
                category: data["category"] || [],
                pub_date: data["pubDate"]
              )

              saved_articles << article

              # Add to sets so if "Tech" and "Business" both return the same article,
              # we skip it in the second category's loop.
              existing_links << data["link"]
              existing_titles << data["title"]

              Rails.logger.info "    [CREATED] ID: #{article.id} | #{article.title[0..30]}..."
            rescue => e
              Rails.logger.error "    [SAVE FAILED] for #{data['link']}: #{e.message}"
            end
          end
        else
          Rails.logger.error "[API ERROR] #{category} failed | Code: #{response.code} | Message: #{response.body}"
        end
      end

      Rails.logger.info "--- Fetch Cycle Complete | Total Processed: #{saved_articles.size} ---"
      saved_articles
    end
  end
end
