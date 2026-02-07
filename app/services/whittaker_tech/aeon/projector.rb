# frozen_string_literal: true

require 'digest/sha2'

module WhittakerTech
  module Aeon
    # Stateless service that expands an {Allocation} into materialised
    # {Occurrence} rows. Operates within a single +FOR UPDATE NOWAIT+
    # transaction to guarantee exclusive access.
    #
    # Projection is:
    # - **Monotonic** — +projected_until+ only moves forward.
    # - **Idempotent** — +INSERT ON CONFLICT DO NOTHING+ prevents duplicates.
    # - **Bounded** — capped by {Configuration#max_projection_window} and
    #   the allocation's +valid_to+.
    # - **Batched** — large result sets are sliced into {UPSERT_BATCH_SIZE}
    #   chunks to prevent unbounded SQL statements.
    #
    # @example Project an allocation 30 days ahead
    #   Projector.call(allocation_id: alloc.id, target_until: 30.days.from_now)
    class Projector
      # @param allocation_id [String] UUID of the allocation to project
      # @param target_until [Time] desired projection horizon
      # @return [void]
      def self.call(allocation_id:, target_until:)
        new(allocation_id: allocation_id, target_until: target_until).call
      end

      # @param allocation_id [String] UUID of the allocation to project
      # @param target_until [Time] desired projection horizon
      def initialize(allocation_id:, target_until:)
        @allocation_id = allocation_id
        @target_until = target_until
      end

      # Locks the allocation, expands occurrences from +projected_until+ to the
      # capped horizon, upserts rows, and advances the frontier.
      #
      # @return [void]
      def call
        Allocation.transaction do
          Allocation.connection.execute("SET LOCAL aeon.bypass_guard = 'true'")
          allocation = lock_allocation!
          return if already_projected?(allocation)

          cap_target!(allocation)
          rows = expand(allocation)
          upsert!(rows) if rows.any?
          advance_frontier!(allocation)
        end
      end

      # Maximum number of rows per +insert_all+ call.
      UPSERT_BATCH_SIZE = 5_000

      private

      # Acquires a +FOR UPDATE NOWAIT+ row lock on the allocation.
      # @return [Allocation]
      # @raise [ActiveRecord::RecordNotFound] if allocation does not exist
      def lock_allocation!
        Allocation.lock('FOR UPDATE NOWAIT').find(@allocation_id)
      end

      # @return [Boolean] true if +projected_until+ already meets or exceeds
      #   the requested target
      def already_projected?(allocation)
        allocation.projected_until >= @target_until
      end

      # Clamps the target horizon to the lesser of +max_projection_window+ and
      # +valid_to+, storing the result in +@capped_until+.
      def cap_target!(allocation)
        max_window = WhittakerTech::Aeon.configuration.max_projection_window
        ceiling = allocation.starts_at + max_window
        ceiling = [ceiling, allocation.valid_to].min if allocation.valid_to
        @capped_until = [@target_until, ceiling].min
        @projection_start = allocation.projected_until
      end

      # Dispatches to the appropriate expander based on +temporal_kind+.
      # @return [Array<Hash>] row hashes ready for +insert_all+
      def expand(allocation)
        case allocation.temporal_kind
        when 'instant'  then expand_instant(allocation)
        when 'span'     then expand_span(allocation)
        when 'schedule' then expand_schedule(allocation)
        end
      end

      # @return [Array<Hash>] zero or one row for a point-in-time allocation
      def expand_instant(allocation)
        return [] if allocation.starts_at < @projection_start

        [build_row(allocation, allocation.starts_at, allocation.starts_at)]
      end

      # @return [Array<Hash>] zero or one row for a fixed-duration allocation
      def expand_span(allocation)
        return [] if allocation.starts_at < @projection_start

        ends_at = allocation.starts_at + (allocation.duration_seconds || 0)
        [build_row(allocation, allocation.starts_at, ends_at)]
      end

      # Expands an IceCube recurrence rule into occurrence rows between
      # +@projection_start+ and +@capped_until+.
      # @return [Array<Hash>]
      def expand_schedule(allocation)
        schedule = build_ice_cube_schedule(allocation)
        candidates = schedule.occurrences_between(@projection_start, @capped_until)
        duration = allocation.duration_seconds || 0

        candidates.map do |start_time|
          starts_at = start_time.utc
          ends_at = starts_at + duration
          build_row(allocation, starts_at, ends_at)
        end
      end

      # @return [IceCube::Schedule]
      def build_ice_cube_schedule(allocation)
        IceCube::Schedule.from_hash(allocation.rrule.deep_symbolize_keys)
      end

      # Builds a hash suitable for +insert_all+ from a start/end pair.
      # @return [Hash]
      def build_row(allocation, starts_at, ends_at)
        {
          allocation_id: allocation.id,
          time_range: "[#{starts_at.iso8601},#{ends_at.iso8601})",
          starts_at: starts_at,
          ends_at: ends_at,
          state: 0,
          projection_fingerprint: fingerprint(allocation),
          projected_at: Time.current
        }
      end

      # Computes a SHA-256 digest of the allocation's temporal parameters,
      # used to detect rrule drift across projections.
      # @return [String] hex-encoded SHA-256 digest
      def fingerprint(allocation)
        payload = [
          allocation.rrule.to_json,
          allocation.starts_at.iso8601,
          allocation.duration_seconds,
          allocation.timezone
        ].join(':')
        Digest::SHA256.hexdigest(payload)
      end

      # Upserts occurrence rows in batches. Uses +ON CONFLICT DO NOTHING+ on
      # the +(allocation_id, starts_at)+ unique index for idempotency.
      def upsert!(rows)
        rows.each_slice(UPSERT_BATCH_SIZE) do |batch|
          Occurrence.insert_all(batch, unique_by: %i[allocation_id starts_at])
        end
      end

      # Advances +projected_until+ via +update_column+ (bypasses callbacks).
      def advance_frontier!(allocation)
        allocation.update_column(:projected_until, @capped_until)
      end
    end
  end
end
