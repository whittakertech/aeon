module WhittakerTech
  module Aeon
    module Schedulable
      extend ActiveSupport::Concern

      class_methods do
        def schedule(name, dependent: :nullify)
          has_one name,
                  -> { where(valid_to: nil) },
                  as: :schedulable,
                  class_name: "WhittakerTech::Aeon::Allocation",
                  inverse_of: :schedulable,
                  dependent: dependent

          has_many :"#{name}_occurrences",
                   through: name,
                   source: :occurrences,
                   class_name: "WhittakerTech::Aeon::Occurrence"

          define_method(:fork_future) do |pivot:, **new_attrs|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc
            Forker.call(allocation_id: alloc.id, pivot: pivot, **new_attrs)
          end

          define_method(:fork_all) do |**new_attrs|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc
            Forker.call(allocation_id: alloc.id, pivot: alloc.valid_from, **new_attrs)
          end

          define_method(:override_occurrence) do |starts_at:, **override_attrs|
            alloc = send(name)
            raise ArgumentError, "no active #{name} allocation" unless alloc
            occurrence = alloc.occurrences.find_by!(starts_at: starts_at)
            OverrideApplier.call(occurrence_id: occurrence.id, **override_attrs)
          end

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
