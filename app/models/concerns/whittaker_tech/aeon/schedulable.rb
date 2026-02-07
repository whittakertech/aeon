# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # DSL concern for host models that own a temporal allocation. Including
    # this module and calling +schedule :name+ wires up associations and
    # convenience verbs so the host never manipulates allocations directly.
    #
    # @example
    #   class Lesson < ApplicationRecord
    #     include WhittakerTech::Aeon::Schedulable
    #     schedule :time_slot
    #   end
    #
    #   lesson.time_slot             # => active Allocation (valid_to IS NULL)
    #   lesson.time_slot_occurrences # => Occurrence collection via :through
    #   lesson.fork_future(pivot: 1.week.from_now, rrule: new_rule)
    #   lesson.fork_all(rrule: new_rule)
    #   lesson.override_occurrence(starts_at: t, canceled: true)
    #   lesson.ensure_projected!(window: 30.days)
    module Schedulable
      extend ActiveSupport::Concern

      class_methods do
        # Declares a named temporal schedule on the host model.
        #
        # Generates:
        # - +has_one :name+ — the active {Allocation} (scoped +valid_to: nil+)
        # - +has_many :name_occurrences+ — {Occurrence} records via +:through+
        # - +#fork_future(pivot:, **new_attrs)+ — delegates to {Forker}
        # - +#fork_all(**new_attrs)+ — delegates to {Forker} at +valid_from+
        # - +#override_occurrence(starts_at:, **attrs)+ — delegates to {OverrideApplier}
        # - +#ensure_projected!(window:)+ — delegates to {Projector}
        #
        # @param name [Symbol] association name (e.g. +:time_slot+)
        # @param dependent [Symbol] dependency strategy for the +has_one+
        #   association (default: +:nullify+)
        # @return [void]
        def schedule(name, dependent: :nullify)
          has_one name,
                  -> { where(valid_to: nil, schedulable_label: name.to_s) },
                  as: :schedulable,
                  class_name: 'WhittakerTech::Aeon::Allocation',
                  inverse_of: :schedulable,
                  dependent: dependent

          has_many :"#{name}_occurrences",
                   through: name,
                   source: :occurrences,
                   class_name: 'WhittakerTech::Aeon::Occurrence'

          # @!method fork_future(pivot:, **new_attrs)
          #   Forks the active allocation at the given pivot, closing the
          #   current allocation and creating a successor with the supplied
          #   attribute overrides.
          #   @param pivot [Time] the point in time at which to fork
          #   @param new_attrs [Hash] attribute overrides for the successor
          #   @return [Allocation] the newly created successor allocation
          #   @raise [ArgumentError] if no active allocation exists
          define_method(:fork_future) do |pivot:, **new_attrs|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc

            Forker.call(allocation_id: alloc.id, pivot: pivot, **new_attrs)
          end

          # @!method fork_all(**new_attrs)
          #   Replaces the entire allocation by forking at +valid_from+,
          #   invalidating all existing occurrences.
          #   @param new_attrs [Hash] attribute overrides for the successor
          #   @return [Allocation] the newly created successor allocation
          #   @raise [ArgumentError] if no active allocation exists
          define_method(:fork_all) do |**new_attrs|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc

            Forker.call(allocation_id: alloc.id, pivot: alloc.valid_from, **new_attrs)
          end

          # @!method override_occurrence(starts_at:, **override_attrs)
          #   Applies a surgical override (cancellation or reschedule) to a
          #   single occurrence identified by +starts_at+.
          #   @param starts_at [Time] the +starts_at+ of the target occurrence
          #   @param override_attrs [Hash] passed to {OverrideApplier}
          #     (+:canceled+, +:replacement_time_range+)
          #   @return [Override]
          #   @raise [ArgumentError] if no active allocation exists
          #   @raise [ActiveRecord::RecordNotFound] if no matching occurrence
          define_method(:override_occurrence) do |starts_at:, **override_attrs|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc

            occurrence = alloc.occurrences.find_by!(starts_at: starts_at)
            OverrideApplier.call(occurrence_id: occurrence.id, **override_attrs)
          end

          # @!method ensure_projected!(window:)
          #   Ensures the active allocation is projected at least +window+ into
          #   the future from now. No-op if already projected past the target.
          #   @param window [ActiveSupport::Duration] how far ahead to project
          #     (default: {Configuration#projection_buffer})
          #   @return [void]
          #   @raise [ArgumentError] if no active allocation exists
          define_method(:ensure_projected!) do |window: WhittakerTech::Aeon.configuration.projection_buffer|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc

            target = Time.current + window
            Projector.call(allocation_id: alloc.id, target_until: target)
          end
        end
      end
    end
  end
end
