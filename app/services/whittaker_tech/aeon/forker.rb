module WhittakerTech
  module Aeon
    class Forker
      def self.call(allocation_id:, pivot:, **new_attrs)
        new(allocation_id: allocation_id, pivot: pivot, new_attrs: new_attrs).call
      end

      def initialize(allocation_id:, pivot:, new_attrs:)
        @allocation_id = allocation_id
        @pivot = pivot
        @new_attrs = new_attrs
      end

      def call
        Allocation.transaction do
          old_allocation = lock_allocation!
          validate_pivot!(old_allocation)
          close_allocation!(old_allocation)
          new_allocation = create_successor!(old_allocation)
          invalidate_future_occurrences!(old_allocation, new_allocation)
          project_successor!(new_allocation)
          new_allocation
        end
      end

      private

      def lock_allocation!
        Allocation.lock("FOR UPDATE NOWAIT").find(@allocation_id)
      end

      def validate_pivot!(old_allocation)
        if @pivot < old_allocation.valid_from
          raise ArgumentError, "pivot cannot be before allocation valid_from (#{old_allocation.valid_from.iso8601})"
        end

        if old_allocation.valid_to.present?
          raise ArgumentError, "allocation is already closed (valid_to: #{old_allocation.valid_to.iso8601})"
        end
      end

      def close_allocation!(old_allocation)
        old_allocation.update_columns(valid_to: @pivot)
      end

      def create_successor!(old_allocation)
        Allocation.create!(
          schedulable_type: old_allocation.schedulable_type,
          schedulable_id: old_allocation.schedulable_id,
          temporal_kind: @new_attrs.fetch(:temporal_kind, old_allocation.temporal_kind),
          starts_at: @new_attrs.fetch(:starts_at, @pivot),
          duration_seconds: @new_attrs.fetch(:duration_seconds, old_allocation.duration_seconds),
          timezone: @new_attrs.fetch(:timezone, old_allocation.timezone),
          rrule: @new_attrs.fetch(:rrule, old_allocation.rrule),
          disposal_policy: @new_attrs.fetch(:disposal_policy, old_allocation.disposal_policy),
          valid_from: @pivot,
          valid_to: nil,
          projected_until: @pivot,
          supersedes_allocation_id: old_allocation.id
        )
      end

      def invalidate_future_occurrences!(old_allocation, new_allocation)
        scope = Occurrence.where(allocation_id: old_allocation.id)
                          .where(invalidated_at: nil)

        # When pivot == valid_from (fork-all), invalidate every occurrence.
        # The starts_at filter is skipped because IceCube truncates times to
        # millisecond precision while PG timestamptz preserves microseconds,
        # so the earliest occurrence can precede valid_from by < 1 ms.
        scope = scope.where("starts_at >= ?", @pivot) unless @pivot == old_allocation.valid_from

        scope.update_all(
          invalidated_at: Time.current,
          invalidated_by_allocation_id: new_allocation.id
        )
      end

      def project_successor!(new_allocation)
        target = @pivot + WhittakerTech::Aeon.configuration.projection_buffer
        Projector.call(allocation_id: new_allocation.id, target_until: target)
      end
    end
  end
end
