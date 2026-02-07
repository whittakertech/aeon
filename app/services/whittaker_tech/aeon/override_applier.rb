# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Stateless service that applies a surgical single-instance deviation to an
    # {Occurrence}. Creates an {Override} row — either a cancellation or a
    # replacement time range. Never triggers re-projection.
    #
    # A DB unique index ensures at most one override per occurrence.
    #
    # @example Cancel an occurrence
    #   OverrideApplier.call(occurrence_id: occ.id, canceled: true)
    #
    # @example Reschedule an occurrence
    #   OverrideApplier.call(occurrence_id: occ.id, replacement_time_range: new_range)
    class OverrideApplier
      # @param occurrence_id [String] UUID of the occurrence to override
      # @param canceled [Boolean] whether to cancel the occurrence (default: false)
      # @param replacement_time_range [String, nil] PG tstzrange literal for
      #   rescheduling (mutually exclusive with +canceled: true+, though both
      #   may be set)
      # @return [Override] the created override record
      def self.call(occurrence_id:, canceled: false, replacement_time_range: nil)
        new(
          occurrence_id: occurrence_id,
          canceled: canceled,
          replacement_time_range: replacement_time_range
        ).call
      end

      # @param occurrence_id [String] UUID of the occurrence to override
      # @param canceled [Boolean] whether to cancel the occurrence
      # @param replacement_time_range [String, nil] replacement tstzrange
      def initialize(occurrence_id:, canceled:, replacement_time_range:)
        @occurrence_id = occurrence_id
        @canceled = canceled
        @replacement_time_range = replacement_time_range
      end

      # Finds the occurrence, validates it, and creates the override.
      #
      # @return [Override]
      # @raise [ActiveRecord::RecordNotFound] if the occurrence does not exist
      # @raise [ArgumentError] if the occurrence is invalidated or no action
      #   (neither +canceled+ nor +replacement_time_range+) is specified
      def call
        occurrence = find_occurrence!
        validate_occurrence!(occurrence)
        create_override!(occurrence)
      end

      private

      # @return [Occurrence]
      # @raise [ActiveRecord::RecordNotFound]
      def find_occurrence!
        Occurrence.find(@occurrence_id)
      end

      # @raise [ArgumentError] if the occurrence is already invalidated or if
      #   neither a cancellation nor a replacement range was provided
      def validate_occurrence!(occurrence)
        raise ArgumentError, 'cannot override an invalidated occurrence' if occurrence.invalidated_at.present?

        return unless !@canceled && @replacement_time_range.nil?

        raise ArgumentError, 'must provide canceled: true or a replacement_time_range'
      end

      # @return [Override]
      def create_override!(occurrence)
        Override.create!(
          occurrence_id: occurrence.id,
          canceled: @canceled,
          replacement_time_range: @replacement_time_range
        )
      end
    end
  end
end
