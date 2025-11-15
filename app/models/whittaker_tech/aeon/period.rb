module WhittakerTech
  module Aeon
    class Period
      include Comparable

      attr_reader :starts_at, :ends_at

      # Create a Period from absolute start and end times
      def initialize(starts_at:, ends_at:)
        @starts_at = starts_at.is_a?(Time) ? starts_at : starts_at.to_time
        @ends_at = ends_at.is_a?(Time) ? ends_at : ends_at.to_time
        validate_bounds
      end

      # Create a Period from start time and duration
      def self.with_duration(starts_at:, duration:)
        new(starts_at:, ends_at: starts_at + duration)
      end

      # Duration in seconds
      def duration
        ends_at - starts_at
      end

      # Duration as ActiveSupport::Duration
      def duration_as_span
        ActiveSupport::Duration.build(duration)
      end

      # Shift forward by delta
      def >>(delta)
        delta_seconds = to_seconds(delta)
        self.class.new(starts_at: starts_at + delta_seconds, ends_at: ends_at + delta_seconds)
      end

      # Shift backward by delta
      def <<(delta)
        delta_seconds = to_seconds(delta)
        self.class.new(starts_at: starts_at - delta_seconds, ends_at: ends_at - delta_seconds)
      end

      # Grow (extend end) by delta
      def +(delta)
        delta_seconds = to_seconds(delta)
        self.class.new(starts_at:, ends_at: ends_at + delta_seconds)
      end

      # Shrink (reduce end) by delta
      def -(delta)
        delta_seconds = to_seconds(delta)
        self.class.new(starts_at:, ends_at: ends_at - delta_seconds)
      end

      # Scale around start point by factor
      def *(factor)
        new_duration = duration * factor
        self.class.new(starts_at:, ends_at: starts_at + new_duration)
      end

      # Scale by reciprocal
      def /(factor)
        raise ZeroDivisionError if factor.to_f.zero?
        self * (1.0 / factor)
      end

      # Check if time falls within period
      def include?(time)
        t = time.is_a?(Time) ? time : time.to_time
        starts_at <= t && t < ends_at
      end

      # Check if another period overlaps
      def overlaps?(other)
        starts_at < other.ends_at && other.starts_at < ends_at
      end

      # Check if another period is fully contained
      def contains?(other)
        starts_at <= other.starts_at && other.ends_at <= ends_at
      end

      # Merge with another period
      def merge(other)
        self.class.new(
          starts_at: [starts_at, other.starts_at].min,
          ends_at: [ends_at, other.ends_at].max
        )
      end

      # Compare periods
      def <=>(other)
        return nil unless other.is_a?(Period)
        [starts_at, ends_at] <=> [other.starts_at, other.ends_at]
      end

      def ==(other)
        other.is_a?(Period) && starts_at == other.starts_at && ends_at == other.ends_at
      end

      def hash
        [starts_at, ends_at].hash
      end

      def to_range
        starts_at..ends_at
      end

      def inspect
        "#<WhittakerTech::Aeon::Period #{starts_at.iso8601}...#{ends_at.iso8601} (#{(duration / 3600).to_i}h)>"
      end

      private

      def validate_bounds
        raise ArgumentError, "starts_at must be before ends_at" if starts_at >= ends_at
      end

      def to_seconds(delta)
        case delta
        when Numeric
          delta
        when ActiveSupport::Duration
          delta.to_i
        when Period, Range
          (delta.respond_to?(:end) ? delta.end : delta.ends_at) - (delta.respond_to?(:begin) ? delta.begin : delta.starts_at)
        else
          raise ArgumentError, "Unsupported delta type: #{delta.class}"
        end
      end
    end
  end
end
