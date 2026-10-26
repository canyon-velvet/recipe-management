source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.7"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Pagination
gem "pagy", "~> 43.8"

# Locale data (validation messages, dates) for zh-CN
gem "rails-i18n", "~> 8.0"

# Server-side markdown rendering
gem "redcarpet", "~> 3.6"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Background jobs, Action Cable and Rails.cache, each kept in the app's Postgres database: no Redis. The jobs run
# inside Puma (config/puma.rb).
gem "solid_queue", "~> 1.2"
gem "solid_cable", "~> 4.1"
gem "solid_cache", "~> 1.0"
# Admins' dashboard of the jobs: queued, running, failed
gem "mission_control-jobs", "~> 1.1"

# Fetches imported recipe pages without letting a link reach private or internal addresses (SSRF)
gem "ssrf_filter", "~> 1.6"

# Claude cleans imported recipes (official Anthropic SDK)
gem "anthropic", "~> 2.2"

# Tells an imported screenshot's type from its bytes
gem "marcel", "~> 1.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec test framework and FactoryBot test data
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  # Drives system specs with Playwright; keep its version in step with "playwright" in package.json
  gem "capybara-playwright-driver", "~> 0.5"
  gem "playwright-ruby-client", "1.63.0"
end
