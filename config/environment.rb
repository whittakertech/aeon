ENV["RAILS_ENV"] = "test"

require "rails"
require "rails/all"
require "rspec/rails"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.cache_classes = true
    config.active_record.sqlite_database_path = ":memory:"
    config.logger = Logger.new(nil)
    config.log_level = :debug
  end
end

Rails.application.initialize!

require "whittaker_tech/aeon"

# Load engine models and services automatically
ActiveSupport::Dependencies.autoload_paths += [
  File.expand_path("../../../app/models", __FILE__),
  File.expand_path("../../../app/services", __FILE__)
]
