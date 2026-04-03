# Be sure to restart your server when you modify this file.

# Configure Solid Queue to load recurring job definitions from config/recurring.yml.
# Without this, the Solid Queue supervisor starts but never registers the scheduled
# tasks, so jobs like IngestNewsJob and AutomatedAnalysisJob are never enqueued.
Rails.application.configure do
  config.solid_queue.recurring_schedule_file = Rails.root.join("config/recurring.yml")
end
