# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Periodic background job that delegates to {Disposer} for policy-driven
    # purge of invalidated occurrences. Takes no arguments — the Disposer scans
    # globally using the engine configuration.
    #
    # The host app is responsible for scheduling this periodically (e.g. via
    # sidekiq-cron, whenever, or similar).
    #
    # @example Enqueue manually
    #   DisposalJob.perform_later
    class DisposalJob < ApplicationJob
      queue_as :aeon_disposal

      # @return [void]
      def perform
        Disposer.call
      end
    end
  end
end
