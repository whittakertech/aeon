module WhittakerTech
  module Aeon
    class Timestamp < ApplicationRecord
      self.table_name = "wt_aeon_timestamps"

      # Polymorphic association to host model
      belongs_to :schedulable, polymorphic: true, optional: false

      # Validations
      validates :starts_at, presence: true
      validates :duration, presence: true, numericality: { greater_than: 0, only_integer: true }
      validates :timezone, presence: true
      validates :repetition_rules, presence: true

      # Callbacks
      after_commit :invalidate_cache, on: [:create, :update]
      after_commit :emit_created, on: :create
      after_commit :emit_updated, on: :update
      after_destroy :invalidate_cache

      # Generate Period from timestamp data
      def to_period
        Period.new(starts_at:, ends_at: calculated_end_at)
      end

      # Calculate end time from duration
      def calculated_end_at
        starts_at + duration
      end

      # Alias for consistency
      def ends_at
        calculated_end_at
      end

      # Check if this is a recurring event
      def recurring?
        repetition_rules.present? && repetition_rules["frequency"].present?
      end

      # Get next occurrence after a given time
      def next_occurrence_after(time)
        return nil unless recurring?

        adapter = RecurrenceAdapter.new(self)
        adapter.next_occurrence_after(time)
      end

      # Get occurrences within a period
      def occurrences_in(period)
        adapter = RecurrenceAdapter.new(self)
        adapter.occurrences_between(period)
      end

      private

      def invalidate_cache
        CacheInvalidation.on_change(self) if Rails.env.production? || Rails.env.test?
      end

      def emit_created
        # Placeholder for Argus integration
        # Argus.emit("aeon.timestamp.created", meta: { id:, schedulable_type:, schedulable_id: })
      end

      def emit_updated
        # Placeholder for Argus integration
        # Argus.emit("aeon.timestamp.updated", meta: { id:, schedulable_type:, schedulable_id: })
      end
    end
  end
end
