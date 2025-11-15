require "ice_cube"

module WhittakerTech
  module Aeon
    class RecurrenceAdapter
      def initialize(timestamp)
        @timestamp = timestamp
      end

      # Get IceCube schedule from timestamp rules
      def schedule
        @schedule ||= build_schedule
      end

      # Get occurrences between two times
      def occurrences_between(period)
        return [@timestamp.to_period] unless @timestamp.recurring?

        schedule
          .occurrences_between(@timestamp.starts_at, period.ends_at)
          .select { |occ| occ >= period.starts_at }
          .map { |occ| Occurrence.new(@timestamp, occ) }
      end

      # Fetch the next occurrence after a given time
      def next_occurrence_after(time)
        return @timestamp.to_period if !@timestamp.recurring? && @timestamp.starts_at >= time

        occ = schedule.next_occurrence(time)
        occ ? Occurrence.new(@timestamp, occ) : nil
      end

      # Serialize schedule back to JSON
      def to_hash
        return @timestamp.repetition_rules if @timestamp.repetition_rules.empty?

        rules = @timestamp.repetition_rules.dup
        # Preserve the serialized form; IceCube manages mutations via schedule object
        rules
      end

      private

      def build_schedule
        IceCube::Schedule.new(@timestamp.starts_at).tap do |sched|
          rules = @timestamp.repetition_rules || {}
          frequency = rules["frequency"]

          if frequency
            rule = build_recurrence_rule(rules)
            sched.add_recurrence_rule(rule)
          end

          # Add exception dates if present
          if rules["exception_dates"].present?
            rules["exception_dates"].each do |date_str|
              sched.add_exception_time(Time.parse(date_str))
            end
          end
        end
      end

      def build_recurrence_rule(rules)
        frequency = rules["frequency"].to_sym
        interval = rules["interval"] || 1

        rule = IceCube::Rule.send(frequency, interval)

        # Apply day restrictions
        if rules["by_day"].present?
          days = rules["by_day"].map(&:to_sym)
          rule.day(*days)
        end

        # Apply until cutoff
        if rules["until"].present?
          rule.until(Time.parse(rules["until"]))
        end

        rule
      end
    end

    # Represents a single occurrence of an event
    class Occurrence
      attr_reader :timestamp, :starts_at

      def initialize(timestamp, ice_cube_occurrence)
        @timestamp = timestamp
        @starts_at = ice_cube_occurrence
      end

      def ends_at
        starts_at + timestamp.duration
      end

      def duration
        timestamp.duration
      end

      def schedulable
        timestamp.schedulable
      end

      def to_period
        Period.new(starts_at:, ends_at:)
      end

      def inspect
        "#<Occurrence #{starts_at.iso8601}...#{ends_at.iso8601}>"
      end
    end
  end
end
