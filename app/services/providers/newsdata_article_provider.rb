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

      if @api_key.blank?
        Rails.logger.error "Aborting fetch: No API Key."
        return []
      end

      Rails.logger.info "--- Starting NewsData Fetch Cycle ---"

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

          if articles_data.empty?
            Rails.logger.warn "  [EMPTY] API returned success but 0 results for #{category}."
          else
            Rails.logger.info "  [SUCCESS] Found #{articles_data.size} articles."
          end

          articles_data.each do |data|
            # We use link as the unique identifier
            article = Article.find_or_initialize_by(link: data["link"])
            is_new = article.new_record?

            begin
              article.update!(
                title: data["title"],
                keywords: data["keywords"] || [],
                category: data["category"] || [],
                pub_date: data["pubDate"]
              )

              saved_articles << article
              Rails.logger.info "    #{is_new ? '[CREATED]' : '[UPDATED]'} ID: #{article.id} | #{article.title[0..40]}..."
            rescue => e
              Rails.logger.error "    [SAVE FAILED] for #{data['link']}: #{e.message}"
            end
          end
        else
          # This is the most important log for you right now
          Rails.logger.error "[API ERROR] #{category} failed | Code: #{response.code} | Message: #{response.body}"
        end
      end

      Rails.logger.info "--- Fetch Cycle Complete | Total Processed: #{saved_articles.size} ---"
      saved_articles
    end
  end
end
