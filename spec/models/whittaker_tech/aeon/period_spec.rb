require "spec_helper"

describe WhittakerTech::Aeon::Period do
  let(:start_time) { Time.new(2025, 3, 1, 0, 0, 0, "+00:00") }
  let(:end_time) { Time.new(2025, 3, 31, 23, 59, 59, "+00:00") }
  let(:period) { described_class.new(starts_at: start_time, ends_at: end_time) }

  describe "initialization" do
    it "creates a period with start and end times" do
      expect(period.starts_at).to eq(start_time)
      expect(period.ends_at).to eq(end_time)
    end

    it "raises if start >= end" do
      expect { described_class.new(starts_at: end_time, ends_at: start_time) }
        .to raise_error(ArgumentError)
    end
  end

  describe "#duration" do
    it "returns duration in seconds" do
      expect(period.duration).to be_a(Numeric)
      expect(period.duration).to be > 0
    end
  end

  describe "shift operators" do
    it ">> shifts forward" do
      shifted = period >> 1.week
      expect(shifted.starts_at).to eq(period.starts_at + 1.week)
      expect(shifted.ends_at).to eq(period.ends_at + 1.week)
      expect(shifted.duration).to eq(period.duration)
    end

    it "<< shifts backward" do
      shifted = period << 5.days
      expect(shifted.starts_at).to eq(period.starts_at - 5.days)
      expect(shifted.ends_at).to eq(period.ends_at - 5.days)
    end
  end

  describe "grow/shrink operators" do
    it "+ grows period" do
      grown = period + 1.week
      expect(grown.starts_at).to eq(period.starts_at)
      expect(grown.ends_at).to eq(period.ends_at + 1.week)
    end

    it "- shrinks period" do
      shrunk = period - 5.days
      expect(shrunk.starts_at).to eq(period.starts_at)
      expect(shrunk.ends_at).to eq(period.ends_at - 5.days)
    end
  end

  describe "scale operators" do
    it "* scales around start point" do
      scaled = period * 2
      expect(scaled.starts_at).to eq(period.starts_at)
      expect(scaled.duration).to eq(period.duration * 2)
    end

    it "/ divides duration" do
      scaled = period / 2
      expect(scaled.duration).to be_within(1).of(period.duration / 2)
    end

    it "raises on division by zero" do
      expect { period / 0 }.to raise_error(ZeroDivisionError)
    end
  end

  describe "#include?" do
    it "returns true for times within bounds" do
      time = start_time + 1.week
      expect(period.include?(time)).to be true
    end

    it "returns false for times outside bounds" do
      time = end_time + 1.day
      expect(period.include?(time)).to be false
    end

    it "returns false for start boundary (exclusive end)" do
      expect(period.include?(end_time)).to be false
    end

    it "returns true for start boundary (inclusive)" do
      expect(period.include?(start_time)).to be true
    end
  end

  describe "#overlaps?" do
    it "returns true for overlapping periods" do
      other = described_class.new(
        starts_at: start_time + 10.days,
        ends_at: end_time + 10.days
      )
      expect(period.overlaps?(other)).to be true
    end

    it "returns false for non-overlapping periods" do
      other = described_class.new(
        starts_at: end_time + 1.day,
        ends_at: end_time + 7.days
      )
      expect(period.overlaps?(other)).to be false
    end
  end

  describe "#contains?" do
    it "returns true if period fully contains another" do
      other = described_class.new(
        starts_at: start_time + 5.days,
        ends_at: end_time - 5.days
      )
      expect(period.contains?(other)).to be true
    end

    it "returns false if not fully contained" do
      other = described_class.new(
        starts_at: start_time - 1.day,
        ends_at: end_time - 5.days
      )
      expect(period.contains?(other)).to be false
    end
  end

  describe "comparison" do
    it "compares periods by start and end times" do
      earlier = described_class.new(
        starts_at: start_time - 1.month,
        ends_at: start_time
      )
      expect(earlier < period).to be true
    end

    it "equality checks both bounds" do
      same = described_class.new(starts_at: start_time, ends_at: end_time)
      expect(period).to eq(same)
    end
  end

  describe "#to_range" do
    it "returns a Range from starts_at to ends_at" do
      range = period.to_range
      expect(range).to be_a(Range)
      expect(range.begin).to eq(start_time)
      expect(range.end).to eq(end_time)
    end
  end

  describe "immutability" do
    it "returns new instances on mutations" do
      original = period.dup
      shifted = period >> 1.week

      expect(period).to eq(original)
      expect(shifted).not_to eq(period)
    end
  end
end
