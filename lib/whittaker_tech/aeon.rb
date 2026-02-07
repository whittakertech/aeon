# frozen_string_literal: true

require 'ice_cube'

module WhittakerTech
  # Temporal physics engine for Rails. Projects immutable temporal laws
  # (Allocations) into materialized Occurrences while preserving historical
  # integrity through forward-only timeline forking.
  #
  # All tables live in the +wt_aeon+ PostgreSQL schema, governed by
  # {.table_name_prefix}.
  #
  # @example Configure the engine
  #   WhittakerTech::Aeon.configure do |c|
  #     c.projection_buffer        = 30.days
  #     c.max_projection_window    = 2.years
  #     c.disposal_policy          = :windowed
  #   end
  module Aeon
    # ActiveRecord table name prefix. Maps models to the +wt_aeon+ PG schema.
    #
    # @return [String] +"wt_aeon."+
    def self.table_name_prefix
      'wt_aeon.'
    end

    # Engine-wide settings controlling projection behaviour and background
    # processing. Obtain via {Aeon.configuration} or mutate via {Aeon.configure}.
    class Configuration
      # @return [ActiveSupport::Duration] how far ahead projection extends
      #   beyond the current time (default: 14 days)
      # @return [ActiveSupport::Duration] absolute ceiling on projection range
      #   from an allocation's +starts_at+ (default: 1 year)
      # @return [Symbol] retention strategy for invalidated occurrences
      #   (+:windowed+, +:permanent+, etc.) (default: +:windowed+)
      # @return [ActiveSupport::Duration] how long invalidated occurrences are
      #   kept before the Disposer may purge them (default: 60 days)
      # @return [Symbol] ActiveJob queue backend (+:sidekiq+, +:async+, etc.)
      attr_accessor :projection_buffer, :max_projection_window,
                    :disposal_policy, :invalidated_retention_window,
                    :queue_adapter

      def initialize
        @projection_buffer = 14.days
        @max_projection_window = 1.year
        @disposal_policy = :windowed
        @invalidated_retention_window = 60.days
        @queue_adapter = :sidekiq
      end
    end

    # Returns the current engine configuration, lazily initialised.
    #
    # @return [Configuration]
    def self.configuration
      @configuration ||= Configuration.new
    end

    # Yields the current {Configuration} for mutation.
    #
    # @yieldparam config [Configuration]
    # @return [void]
    def self.configure
      yield(configuration)
    end
  end
end

require 'whittaker_tech/aeon/version'
require 'whittaker_tech/aeon/engine'
