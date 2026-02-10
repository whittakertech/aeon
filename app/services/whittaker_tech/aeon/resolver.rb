# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Stateless read-path service that merges allocations, occurrences,
    # overrides, and invalidations into a sorted array of frozen
    # {ResolvedOccurrence} value objects.
    #
    # The Resolver answers one question: **"What actually happens within
    # this window?"**
    #
    # It does NOT trigger projection, snapshot hosts, enforce domain rules,
    # or format UI payloads.
    #
    # @example Resolve a 2-week window for a host
    #   Resolver.between(
    #     schedulable: lesson,
    #     range: Time.current..(Time.current + 2.weeks),
    #     label: :time_slot
    #   )
    #   # => [#<ResolvedOccurrence ...>, ...]
    class Resolver
      # @param schedulable [ActiveRecord::Base] host AR object
      # @param range [Range<Time>] query window
      # @param label [String, Symbol, nil] optional schedulable_label filter;
      #   nil returns all labels
      # @return [Array<ResolvedOccurrence>] frozen, sorted by +starts_at+
      def self.between(schedulable:, range:, label: nil)
        new(schedulable: schedulable, range: range, label: label).call
      end

      # @param schedulable [ActiveRecord::Base] host AR object
      # @param range [Range<Time>] query window
      # @param label [String, Symbol, nil] optional label filter
      def initialize(schedulable:, range:, label:)
        @schedulable = schedulable
        @range = range
        @label = label&.to_s
      end

      # Fetches allocations and their active occurrences within the window,
      # applies overrides, and returns frozen value objects.
      #
      # @return [Array<ResolvedOccurrence>]
      def call
        allocations = fetch_allocations
        return [].freeze if allocations.empty?

        label_map = allocations.each_with_object({}) { |a, h| h[a.id] = a.schedulable_label }
        occurrences = fetch_occurrences(allocations)

        resolve(occurrences, label_map).sort_by(&:starts_at).freeze
      end

      private

      # Fetches allocations whose validity window overlaps the query range.
      # @return [Array<Allocation>]
      def fetch_allocations
        scope = Allocation
                .where(schedulable_type: @schedulable.class.name, schedulable_id: @schedulable.id)
                .where(valid_from: ..@range.end)
                .where('valid_to IS NULL OR valid_to > ?', @range.begin)

        scope = scope.where(schedulable_label: @label) if @label

        scope.to_a
      end

      # Fetches active occurrences within the range, eager-loading overrides.
      # @return [Array<Occurrence>]
      def fetch_occurrences(allocations)
        tstzrange = "[#{@range.begin.iso8601},#{@range.end.iso8601})"

        Occurrence.active
                  .where(allocation_id: allocations.map(&:id))
                  .within_range(tstzrange)
                  .includes(:override)
                  .to_a
      end

      # Applies override logic and builds ResolvedOccurrence value objects.
      # @return [Array<ResolvedOccurrence>]
      def resolve(occurrences, label_map)
        occurrences.filter_map do |occ|
          override = occ.override
          next if override&.canceled?

          starts_at = occ.starts_at
          ends_at = occ.ends_at

          if override&.replacement_time_range
            starts_at = override.replacement_time_range.begin
            ends_at = override.replacement_time_range.end

            next unless in_window?(starts_at)
          end

          ResolvedOccurrence.new(
            occurrence_id: occ.id,
            allocation_id: occ.allocation_id,
            starts_at:, ends_at:,
            overridden: override&.replacement_time_range.present?,
            state: occ.state,
            schedulable_label: label_map[occ.allocation_id]
          )
        end
      end

      # Checks if a time falls within the half-open query window [begin, end).
      # @param time [Time]
      # @return [Boolean]
      def in_window?(time)
        time >= @range.begin && time < @range.end
      end
    end
  end
end
