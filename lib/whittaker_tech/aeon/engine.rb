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

      initializer "aeon.migrations" do |app|
        app.config.paths["db/migrate"].concat(config.paths["db/migrate"].expanded)
      end

      initializer "aeon.schema_format" do |app|
        app.config.active_record.schema_format = :sql
      end

      initializer "aeon.table_name_prefix", after: "aeon.schema_format" do
        ActiveSupport.on_load(:active_record) do
          WhittakerTech::Aeon.singleton_class.redefine_method(:table_name_prefix) { "wt_aeon." }
        end
      end
    end
  end
end
