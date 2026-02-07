module WhittakerTech
  module Aeon
    class OverrideApplier
      def self.call(occurrence_id:, canceled: false, replacement_time_range: nil)
        new(
          occurrence_id: occurrence_id,
          canceled: canceled,
          replacement_time_range: replacement_time_range
        ).call
      end

      def initialize(occurrence_id:, canceled:, replacement_time_range:)
        @occurrence_id = occurrence_id
        @canceled = canceled
        @replacement_time_range = replacement_time_range
      end

      def call
        occurrence = find_occurrence!
        validate_occurrence!(occurrence)
        create_override!(occurrence)
      end

      private

      def find_occurrence!
        Occurrence.find(@occurrence_id)
      end

      def validate_occurrence!(occurrence)
        if occurrence.invalidated_at.present?
          raise ArgumentError, "cannot override an invalidated occurrence"
        end

        if !@canceled && @replacement_time_range.nil?
          raise ArgumentError, "must provide canceled: true or a replacement_time_range"
        end
      end

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
