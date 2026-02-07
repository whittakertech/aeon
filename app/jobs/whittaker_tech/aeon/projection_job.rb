module WhittakerTech
  module Aeon
    class ProjectionJob < ApplicationJob
      queue_as :aeon_projection

      def perform(allocation_id, horizon_iso8601)
        Projector.call(
          allocation_id: allocation_id,
          target_until: Time.iso8601(horizon_iso8601)
        )
      end
    end
  end
end
