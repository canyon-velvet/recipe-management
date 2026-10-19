require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint. HSTS covers this host only: with a custom domain
  # (APP_HOSTS) at the domain's root, every subdomain would otherwise be https-only for two years.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } }, hsts: { subdomains: false } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # Solid Cache (config/cache.yml), in the app's database; it holds the rate limits' counters.
  config.cache_store = :solid_cache_store

  # Jobs are queued in the app's database and run inside Puma (config/puma.rb), so no separate worker is needed.
  config.active_job.queue_adapter = :solid_queue
  # When a deploy stops the old server, a reply or import still running gets this long to finish (Solid Queue's own
  # default is 5 seconds; Claude often takes longer). Render waits 60 seconds before killing it (render.yaml).
  config.solid_queue.shutdown_timeout = 50.seconds

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks. Render always sets RENDER_EXTERNAL_HOSTNAME (the
  # *.onrender.com address); APP_HOSTS adds others, comma-separated, such as a custom domain. (With neither, the list
  # would be empty, which turns the protection off.)
  config.hosts = [ ENV["RENDER_EXTERNAL_HOSTNAME"], *ENV.fetch("APP_HOSTS", "").split(",").map(&:strip) ].compact_blank

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
