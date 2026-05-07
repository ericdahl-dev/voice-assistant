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

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # TLS is terminated by the reverse proxy (e.g. Coolify / Traefik). Set RAILS_ASSUME_SSL=false
  # only if the app is reached over plain HTTP end-to-end (not recommended).
  config.assume_ssl = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RAILS_ASSUME_SSL", true))
  config.force_ssl = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RAILS_FORCE_SSL", true))
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

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
  config.cache_store = :solid_cache_store

  # Use GoodJob for background jobs in production.
  config.active_job.queue_adapter = :good_job
  # Jobs are executed by a separate `bundle exec good_job start` process (e.g. Coolify worker).
  config.good_job.execution_mode = :external

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Public hostname (e.g. app.example.com). Used for mailer URLs and Host authorization.
  app_host = ENV["APP_HOST"].presence
  config.action_mailer.default_url_options = {
    host: app_host || "example.com",
    protocol: "https"
  }
  config.hosts << app_host if app_host
  ENV.fetch("RAILS_ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:blank?).each do |host|
    config.hosts << host
  end
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]
end
