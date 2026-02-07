# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Mountable, API-only Rails engine. Provides initializers that:
    # - enforce UUID primary keys for all generated models
    # - set the application time zone and ActiveRecord default to UTC
    # - set +schema_format = :sql+ for faithful +structure.sql+ dumps
    # - re-assert {Aeon.table_name_prefix} after +isolate_namespace+ to keep
    #   models in the +wt_aeon+ PostgreSQL schema
    class Engine < ::Rails::Engine
      isolate_namespace WhittakerTech::Aeon

      # Configure generators to use UUID primary keys by default.
      initializer 'aeon.generators' do |app|
        app.config.generators do |g|
          g.orm :active_record, primary_key_type: :uuid
        end
      end

      config.time_zone = 'UTC'
      config.active_record.default_timezone = :utc

      # Force SQL schema format so +structure.sql+ captures PG-specific
      # features (schemas, GiST indexes, partial indexes, tstzrange columns).
      initializer 'aeon.schema_format' do |app|
        app.config.active_record.schema_format = :sql
      end

      # +isolate_namespace+ redefines +table_name_prefix+ via an
      # +on_load(:active_record)+ callback that always wins over the static
      # method defined in {Aeon}. This initializer registers a later
      # +on_load+ callback to re-assert the prefix, ensuring models resolve
      # to +wt_aeon.*+ tables.
      initializer 'aeon.table_name_prefix', after: 'aeon.schema_format' do
        ActiveSupport.on_load(:active_record) do
          WhittakerTech::Aeon.singleton_class.redefine_method(:table_name_prefix) { 'wt_aeon.' }
        end
      end
    end
  end
end
