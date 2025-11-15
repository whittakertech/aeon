module WhittakerTech
  module Aeon
    class Engine < ::Rails::Engine
      isolate_namespace WhittakerTech::Aeon

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot
        g.factory_bot dir: "spec/factories"
      end

      initializer "whittaker_tech.aeon.load_helpers" do |app|
        app.config.to_prepare do
          # Load concerns and helpers
        end
      end
    end
  end
end
