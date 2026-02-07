require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require "whittaker_tech/aeon"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.root = File.expand_path('..', __dir__)

    # For compatibility with applications that use this app as the
    # temporary Rails application for engine testing.
    config.eager_load = false

    # Discover engine migrations directly for dev/test without running
    # the install generator copy step.
    config.paths['db/migrate'].concat(WhittakerTech::Aeon::Engine.paths['db/migrate'].expanded)
  end
end
