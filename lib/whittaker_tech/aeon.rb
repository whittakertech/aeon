require "ice_cube"

module WhittakerTech
  module Aeon
    def self.table_name_prefix
      "wt_aeon."
    end

    class Configuration
      attr_accessor :projection_buffer, :max_projection_window,
                    :occurrence_retention_policy, :invalidated_retention_window,
                    :queue_adapter

      def initialize
        @projection_buffer = 14.days
        @max_projection_window = 1.year
        @occurrence_retention_policy = :windowed
        @invalidated_retention_window = 60.days
        @queue_adapter = :sidekiq
      end
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end
  end
end

require "whittaker_tech/aeon/version"
require "whittaker_tech/aeon/engine"
