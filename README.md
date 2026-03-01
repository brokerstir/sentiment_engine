# Social Sentiment Engine (MVP)

A high-performance, real-time analytics engine built to observe how different LLMs "think" about trending global topics. This project is a showcase of **Rails 8** best practices, focusing on the "One Person Framework" philosophy: maximum impact with zero infrastructure bloat.

## 🚀 The Stack: "The Solid Trifecta"
Unlike traditional MVPs that require Redis, Sidekiq, and Postgres, this engine leverages the **Rails 8 Solid Stack** to keep the footprint small and the speed high:

- **Framework:** Ruby on Rails 8.0.0 (Ruby 3.3.5 with YJIT enabled)
- **Database:** SQLite (Development) / Turso (Production Edge-Replicated libSQL)
- **Background Jobs:** `Solid Queue` (Database-backed, eliminating Redis)
- **Caching:** `Solid Cache` (High-performance disk/DB caching)
- **Frontend:** Hotwire (Turbo & Stimulus) + Tailwind CSS
- **Deployment:** Dockerized workflow for Render/Fly.io

## 🧠 Core Logic
1. **Ingestion:** Hourly workers fetch trending topics from X (Twitter) and Google Trends.
2. **Analysis:** Dual-model processing (e.g., GPT-4o and Claude 3.5) to map sentiment across 2D coordinates (Tone vs. Political/Social Lean).
3. **Real-time:** Updates are broadcasted via ActionCable (Solid Cable) to a reactive dashboard.

## 🛠 Setup & Development

### Prerequisites
- Ruby 3.3.5 (Managed via `rbenv`)
- Rails 8.0.0
- SQLite 3

### Quick Start
```bash
git clone [https://github.com/brokerstir/sentiment_engine.git](https://github.com/brokerstir/sentiment_engine.git)
cd sentiment_engine
bin/setup
bin/rails s