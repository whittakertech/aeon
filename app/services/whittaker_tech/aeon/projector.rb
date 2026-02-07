require "digest/sha2"

module WhittakerTech
  module Aeon
    class Projector
      def self.call(allocation_id:, target_until:)
        new(allocation_id: allocation_id, target_until: target_until).call
      end

      def initialize(allocation_id:, target_until:)
        @allocation_id = allocation_id
        @target_until = target_until
      end

      def call
        Allocation.transaction do
          allocation = lock_allocation!
          return if already_projected?(allocation)

          cap_target!(allocation)
          rows = expand(allocation)
          upsert!(rows) if rows.any?
          advance_frontier!(allocation)
        end
      end

      private

      def lock_allocation!
        Allocation.lock("FOR UPDATE NOWAIT").find(@allocation_id)
      end

      def already_projected?(allocation)
        allocation.projected_until >= @target_until
      end

      def cap_target!(allocation)
        max_window = WhittakerTech::Aeon.configuration.max_projection_window
        ceiling = allocation.starts_at + max_window
        ceiling = [ceiling, allocation.valid_to].min if allocation.valid_to
        @capped_until = [@target_until, ceiling].min
        @projection_start = allocation.projected_until
      end

      def expand(allocation)
        case allocation.temporal_kind
        when "instant"  then expand_instant(allocation)
        when "span"     then expand_span(allocation)
        when "schedule" then expand_schedule(allocation)
        end
      end

      def expand_instant(allocation)
        return [] if allocation.starts_at < @projection_start

        [build_row(allocation, allocation.starts_at, allocation.starts_at)]
      end

      def expand_span(allocation)
        return [] if allocation.starts_at < @projection_start

        ends_at = allocation.starts_at + (allocation.duration_seconds || 0)
        [build_row(allocation, allocation.starts_at, ends_at)]
      end

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

      def build_ice_cube_schedule(allocation)
        IceCube::Schedule.from_hash(allocation.rrule.deep_symbolize_keys)
      end

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

      def fingerprint(allocation)
        payload = "#{allocation.rrule.to_json}:#{allocation.starts_at.iso8601}:#{allocation.duration_seconds}:#{allocation.timezone}"
        Digest::SHA256.hexdigest(payload)
      end

      def upsert!(rows)
        Occurrence.insert_all(rows, unique_by: [:allocation_id, :starts_at])
      end

      def advance_frontier!(allocation)
        allocation.update_column(:projected_until, @capped_until)
      end
    end
  end
end
