require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.assets.compile = false
  config.log_level = :info
  config.log_tags = [:request_id]
  config.active_support.report_deprecations = false
end
