# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Stateless service that performs forward-only timeline forking. Closes the
    # current {Allocation} at a pivot point, creates a successor with lineage,
    # set-based invalidates future {Occurrence} rows, and inline-projects the
    # new allocation.
    #
    # Two modes:
    # - **Fork future** — +pivot > valid_from+: past occurrences are preserved,
    #   only future ones are invalidated.
    # - **Fork all** — +pivot == valid_from+: every occurrence is invalidated
    #   and the allocation is fully replaced.
    #
    # @example Fork at a future point
    #   Forker.call(allocation_id: alloc.id, pivot: 1.week.from_now, rrule: new_rule)
    #
    # @example Replace entirely (fork all)
    #   Forker.call(allocation_id: alloc.id, pivot: alloc.valid_from, rrule: new_rule)
    class Forker
      # @param allocation_id [String] UUID of the allocation to fork
      # @param pivot [Time] the point at which to split the timeline
      # @param new_attrs [Hash] attribute overrides for the successor allocation
      # @return [Allocation] the newly created successor
      def self.call(allocation_id:, pivot:, **new_attrs)
        new(allocation_id: allocation_id, pivot: pivot, new_attrs: new_attrs).call
      end

      # @param allocation_id [String] UUID of the allocation to fork
      # @param pivot [Time] the point at which to split the timeline
      # @param new_attrs [Hash] attribute overrides for the successor
      def initialize(allocation_id:, pivot:, new_attrs:)
        @allocation_id = allocation_id
        @pivot = pivot
        @new_attrs = new_attrs
      end

      # Executes the fork within a serialised transaction.
      #
      # @return [Allocation] the successor allocation
      def call
        Allocation.transaction do
          Allocation.connection.execute("SET LOCAL aeon.bypass_guard = 'true'")
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

      # @return [Allocation]
      def lock_allocation!
        Allocation.lock('FOR UPDATE NOWAIT').find(@allocation_id)
      end

      # @raise [ArgumentError] if pivot precedes +valid_from+ or if
      #   the allocation is already closed
      def validate_pivot!(old_allocation)
        if @pivot < old_allocation.valid_from
          raise ArgumentError, "pivot cannot be before allocation valid_from (#{old_allocation.valid_from.iso8601})"
        end

        return if old_allocation.valid_to.blank?

        raise ArgumentError, "allocation is already closed (valid_to: #{old_allocation.valid_to.iso8601})"
      end

      # Sets +valid_to+ on the old allocation via +update_columns+ (bypasses
      # the immutability callback).
      def close_allocation!(old_allocation)
        old_allocation.update_columns(valid_to: @pivot)
      end

      # Creates a new allocation inheriting the old one's fields, with
      # +supersedes_allocation_id+ linking to the predecessor.
      # @return [Allocation]
      def create_successor!(old_allocation)
        Allocation.create!(
          schedulable_type: old_allocation.schedulable_type,
          schedulable_id: old_allocation.schedulable_id,
          schedulable_label: old_allocation.schedulable_label,
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

      # Set-based SQL invalidation of future occurrences. When +pivot == valid_from+
      # (fork-all), the +starts_at >=+ filter is skipped to handle IceCube's
      # millisecond truncation vs PG's microsecond precision.
      def invalidate_future_occurrences!(old_allocation, new_allocation)
        scope = Occurrence.where(allocation_id: old_allocation.id)
                          .where(invalidated_at: nil)

        scope = scope.where(starts_at: @pivot..) unless @pivot == old_allocation.valid_from

        scope.update_all(
          invalidated_at: Time.current,
          invalidated_by_allocation_id: new_allocation.id
        )
      end

      # Inline-projects the successor allocation for the configured
      # {Configuration#projection_buffer}.
      def project_successor!(new_allocation)
        target = @pivot + WhittakerTech::Aeon.configuration.projection_buffer
        Projector.call(allocation_id: new_allocation.id, target_until: target)
      end
    end
  end
end
