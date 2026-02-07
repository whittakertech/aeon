# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Enqueue-able wrapper around {Projector} for asynchronous projection.
    # Accepts serialisation-safe arguments (UUID string + ISO 8601 timestamp)
    # so it can travel through any ActiveJob backend.
    #
    # @example Enqueue a projection
    #   ProjectionJob.perform_later(allocation.id, 30.days.from_now.iso8601)
    class ProjectionJob < ApplicationJob
      queue_as :aeon_projection

      # @param allocation_id [String] UUID of the allocation to project
      # @param horizon_iso8601 [String] ISO 8601 timestamp for the projection
      #   horizon (parsed back to +Time+ before delegation)
      # @return [void]
      def perform(allocation_id, horizon_iso8601)
        Projector.call(
          allocation_id: allocation_id,
          target_until: Time.iso8601(horizon_iso8601)
        )
      end
    end
  end
end
