module WhittakerTech
  module Aeon
    class Allocation < ApplicationRecord
      TEMPORAL_FIELDS = %w[
        temporal_kind starts_at duration_seconds timezone rrule
        valid_from valid_to projected_until
        supersedes_allocation_id schedulable_type schedulable_id
      ].freeze

      enum :temporal_kind, { instant: 0, span: 1, schedule: 2 }

      before_update do
        violated = changed & TEMPORAL_FIELDS
        if violated.any?
          raise ActiveRecord::ReadonlyAttributeError,
                "cannot mutate temporal fields on a persisted Allocation: #{violated.join(', ')}"
        end
      end

      belongs_to :schedulable, polymorphic: true

      belongs_to :superseded_allocation,
                 class_name: "WhittakerTech::Aeon::Allocation",
                 foreign_key: :supersedes_allocation_id,
                 inverse_of: :superseding_allocation,
                 optional: true

      has_one :superseding_allocation,
              class_name: "WhittakerTech::Aeon::Allocation",
              foreign_key: :supersedes_allocation_id,
              inverse_of: :superseded_allocation

      has_many :occurrences, inverse_of: :allocation

      has_many :invalidated_occurrences,
               class_name: "WhittakerTech::Aeon::Occurrence",
               foreign_key: :invalidated_by_allocation_id,
               inverse_of: :invalidated_by_allocation
    end
  end
end
