# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Immutable value object returned by {Resolver}. Represents a single
    # occurrence with overrides already applied — the caller sees the
    # effective temporal reality, not the raw projections.
    #
    # This is deliberately NOT an ActiveRecord model. Facts should not
    # feel editable.
    #
    # @attr occurrence_id [String] UUID of the base occurrence
    # @attr allocation_id [String] UUID of the owning allocation
    # @attr starts_at [Time] effective start (replacement if overridden)
    # @attr ends_at [Time] effective end (replacement if overridden)
    # @attr overridden [Boolean] true if a replacement override was applied
    # @attr state [String] occurrence state enum value ("active")
    # @attr schedulable_label [String] schedule label ("time_slot", etc.)
    ResolvedOccurrence = Struct.new(
      :occurrence_id,
      :allocation_id,
      :starts_at,
      :ends_at,
      :overridden,
      :state,
      :schedulable_label,
      keyword_init: true
    )
  end
end
