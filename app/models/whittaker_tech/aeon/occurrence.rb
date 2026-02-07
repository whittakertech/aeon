# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # A materialized prediction projected from an {Allocation}. Each occurrence
    # represents a single point or span on the timeline, with an immutable
    # +time_range+ (tstzrange) backed by a GiST index for efficient range
    # queries.
    #
    # Coordinates (+time_range+, +starts_at+, +ends_at+, +allocation_id+) are
    # frozen after creation. Only invalidation metadata and +state+ may change.
    # Surgical per-instance deviations are expressed via {Override}, not by
    # mutating the occurrence.
    #
    # @see Projector
    # @see OverrideApplier
    class Occurrence < ApplicationRecord
      # Fields that are immutable once the occurrence is persisted.
      # Any AR-level mutation of these triggers +ReadonlyAttributeError+.
      COORDINATE_FIELDS = %w[
        time_range starts_at ends_at allocation_id
      ].freeze

      # @!attribute [rw] state
      #   @return [String] currently only +"active"+ (0)
      enum :state, { active: 0 }

      # Immutability guard — blocks AR-level mutation of coordinate fields.
      before_update do
        violated = changed & COORDINATE_FIELDS
        if violated.any?
          raise ActiveRecord::ReadonlyAttributeError,
                "cannot mutate coordinates on a persisted Occurrence: #{violated.join(', ')}"
        end
      end

      # @!attribute [rw] allocation
      #   The allocation that projected this occurrence.
      #   @return [Allocation]
      belongs_to :allocation, inverse_of: :occurrences

      # @!attribute [rw] invalidated_by_allocation
      #   The successor allocation that caused this occurrence to be invalidated
      #   during a fork operation.
      #   @return [Allocation, nil]
      belongs_to :invalidated_by_allocation,
                 class_name: 'WhittakerTech::Aeon::Allocation',
                 inverse_of: :invalidated_occurrences,
                 optional: true

      # @!attribute [r] override
      #   Optional surgical deviation (cancellation or reschedule).
      #   @return [Override, nil]
      has_one :override, inverse_of: :occurrence

      # @!scope class
      # @!method active
      #   Occurrences that have not been invalidated or purged.
      #   Matches the partial index +idx_aeon_occurrences_active+.
      #   @return [ActiveRecord::Relation]
      scope :active, -> { where(invalidated_at: nil, purged_at: nil) }

      # @!scope class
      # @!method invalidated
      #   Occurrences that have been invalidated by a fork.
      #   @return [ActiveRecord::Relation]
      scope :invalidated, -> { where.not(invalidated_at: nil) }

      # @!scope class
      # @!method within_range(range)
      #   Occurrences whose +time_range+ overlaps the given range, using the
      #   GiST-indexed +&&+ operator.
      #   @param range [Range, String] a PG-compatible tstzrange
      #   @return [ActiveRecord::Relation]
      scope :within_range, ->(range) { where('time_range && ?', range) }
    end
  end
end
