# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_17_093940) do
  create_table "article_analyses", force: :cascade do |t|
    t.integer "article_id", null: false
    t.string "llm_name"
    t.float "bias"
    t.text "summary"
    t.float "heat"
    t.float "evaluation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "reasoning"
    t.index ["article_id", "llm_name"], name: "index_article_analyses_on_article_id_and_llm_name", unique: true
    t.index ["article_id"], name: "index_article_analyses_on_article_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title"
    t.string "link"
    t.json "keywords"
    t.json "category"
    t.datetime "pub_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "disagreement_score"
  end

  create_table "sentiment_analyses", force: :cascade do |t|
    t.string "llm_model"
    t.float "score"
    t.text "reasoning"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.float "intensity"
    t.integer "source_item_id", null: false
    t.float "bias"
    t.index ["source_item_id"], name: "index_sentiment_analyses_on_source_item_id"
  end

  create_table "source_items", force: :cascade do |t|
    t.integer "trend_id", null: false
    t.string "headline"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trend_id"], name: "index_source_items_on_trend_id"
  end

  create_table "trends", force: :cascade do |t|
    t.string "name"
    t.string "source"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "source_provider"
    t.float "gemini_avg_bias", default: 0.0
    t.float "gemini_avg_intensity", default: 0.0
    t.float "gemini_avg_score", default: 0.0
    t.float "grok_avg_bias", default: 0.0
    t.float "grok_avg_intensity", default: 0.0
    t.float "grok_avg_score", default: 0.0
    t.float "gemini_net_bias", default: 0.0
    t.float "grok_net_bias", default: 0.0
    t.float "bias_disagreement", default: 0.0
    t.index ["status"], name: "index_trends_on_status"
  end

  add_foreign_key "article_analyses", "articles"
  add_foreign_key "sentiment_analyses", "source_items"
  add_foreign_key "source_items", "trends"
end
