module WhittakerTech
  module Aeon
    class Engine < ::Rails::Engine
      isolate_namespace WhittakerTech::Aeon

      initializer "aeon.generators" do |app|
        app.config.generators do |g|
          g.orm :active_record, primary_key_type: :uuid
        end
      end

      config.time_zone = "UTC"
      config.active_record.default_timezone = :utc
    end
  end
end
