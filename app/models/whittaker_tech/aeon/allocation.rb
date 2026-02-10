# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # An immutable temporal law attached to a host record via polymorphic
    # +schedulable+. Allocations are never edited in place — future changes
    # are expressed through {Forker}, which closes the current allocation and
    # creates a successor linked via +supersedes_allocation_id+.
    #
    # Temporal fields are protected by a +before_update+ guard that raises
    # {ActiveRecord::ReadonlyAttributeError}. Services bypass this via
    # +update_column+/+update_columns+ which skip callbacks by design.
    #
    # @see Forker
    # @see Projector
    class Allocation < ApplicationRecord
      # Fields that are immutable once the allocation is persisted.
      # Any AR-level mutation of these triggers +ReadonlyAttributeError+.
      TEMPORAL_FIELDS = %w[
        temporal_kind starts_at duration_seconds timezone rrule
        valid_from valid_to projected_until
        supersedes_allocation_id schedulable_type schedulable_id schedulable_label
      ].freeze

      # @!attribute [rw] temporal_kind
      #   @return [String] one of +"instant"+, +"span"+, or +"schedule"+
      enum :temporal_kind, { instant: 0, span: 1, schedule: 2 }

      # Immutability guard — blocks AR-level mutation of temporal coordinates.
      before_update do
        violated = changed & TEMPORAL_FIELDS
        if violated.any?
          raise ActiveRecord::ReadonlyAttributeError,
                "cannot mutate temporal fields on a persisted Allocation: #{violated.join(', ')}"
        end
      end

      validates :schedulable_label,
                presence: true,
                format: { with: /\A[a-z0-9_]+\z/ },
                length: { maximum: 64 }

      before_validation do
        self.schedulable_label = schedulable_label.to_s.strip.downcase.presence if schedulable_label
      end

      # @!attribute [rw] schedulable
      #   The host record this allocation governs (polymorphic).
      belongs_to :schedulable, polymorphic: true

      # @!attribute [rw] superseded_allocation
      #   The predecessor allocation that this one replaces (fork lineage).
      #   @return [Allocation, nil]
      belongs_to :superseded_allocation,
                 class_name: 'WhittakerTech::Aeon::Allocation',
                 foreign_key: :supersedes_allocation_id,
                 inverse_of: :superseding_allocation,
                 optional: true

      # @!attribute [r] superseding_allocation
      #   The successor allocation that replaced this one, if any.
      #   @return [Allocation, nil]
      has_one :superseding_allocation,
              class_name: 'WhittakerTech::Aeon::Allocation',
              foreign_key: :supersedes_allocation_id,
              inverse_of: :superseded_allocation

      # @!attribute [r] occurrences
      #   Materialized occurrences projected from this allocation.
      #   @return [ActiveRecord::Associations::CollectionProxy<Occurrence>]
      has_many :occurrences, inverse_of: :allocation

      # @!attribute [r] invalidated_occurrences
      #   Occurrences from a predecessor allocation that were invalidated when
      #   this allocation was created via a fork.
      #   @return [ActiveRecord::Associations::CollectionProxy<Occurrence>]
      has_many :invalidated_occurrences,
               class_name: 'WhittakerTech::Aeon::Occurrence',
               foreign_key: :invalidated_by_allocation_id,
               inverse_of: :invalidated_by_allocation
    end
  end
end
