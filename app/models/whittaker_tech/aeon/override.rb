# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # A surgical single-instance deviation layered on top of an {Occurrence}.
    # At most one override exists per occurrence (enforced by a DB unique
    # index). An override either cancels the occurrence or provides a
    # +replacement_time_range+ — it never triggers re-projection.
    #
    # Overrides take precedence during reads: query consumers should check
    # for an override and prefer its data over the base occurrence.
    #
    # @see OverrideApplier
    class Override < ApplicationRecord
      # @!attribute [rw] occurrence
      #   The base occurrence this override modifies.
      #   @return [Occurrence]
      belongs_to :occurrence, inverse_of: :override
    end
  end
end
