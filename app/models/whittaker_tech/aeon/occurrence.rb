module WhittakerTech
  module Aeon
    class Occurrence < ApplicationRecord
      COORDINATE_FIELDS = %w[
        time_range starts_at ends_at allocation_id
      ].freeze

      enum :state, { active: 0 }

      before_update do
        violated = changed & COORDINATE_FIELDS
        if violated.any?
          raise ActiveRecord::ReadonlyAttributeError,
                "cannot mutate coordinates on a persisted Occurrence: #{violated.join(', ')}"
        end
      end

      belongs_to :allocation, inverse_of: :occurrences

      belongs_to :invalidated_by_allocation,
                 class_name: "WhittakerTech::Aeon::Allocation",
                 foreign_key: :invalidated_by_allocation_id,
                 inverse_of: :invalidated_occurrences,
                 optional: true

      has_one :override, inverse_of: :occurrence

      scope :active, -> { where(invalidated_at: nil, purged_at: nil) }
      scope :invalidated, -> { where.not(invalidated_at: nil) }
      scope :within_range, ->(range) { where("time_range && ?", range) }
    end
  end
end
