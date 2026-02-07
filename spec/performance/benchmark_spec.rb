require "rails_helper"
require "benchmark"

RSpec.describe "Performance", :performance do
  def build_allocation(frequency:, starts_at: 1.day.from_now.change(usec: 0), duration: 3600)
    rule = case frequency
           when :daily  then IceCube::Rule.daily
           when :weekly then IceCube::Rule.weekly
           when :hourly then IceCube::Rule.hourly
           end

    schedule = IceCube::Schedule.new(starts_at) { |s| s.add_recurrence_rule(rule) }

    create(:allocation,
      temporal_kind: :schedule,
      starts_at: starts_at,
      duration_seconds: duration,
      timezone: "UTC",
      rrule: schedule.to_hash,
      valid_from: starts_at,
      projected_until: starts_at
    )
  end

  describe "Projection throughput" do
    it "projects a daily schedule over 1 year in under 1 second" do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.year

      elapsed = Benchmark.measure {
        WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)
      }.real

      count = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count
      puts "  → Projected #{count} occurrences in #{elapsed.round(3)}s"

      expect(count).to be >= 365
      expect(elapsed).to be < 1.0
    end
  end

  describe "Batch projection at scale" do
    it "projects 100 varied allocations in under 30 seconds" do
      frequencies = [:daily, :weekly, :hourly]
      allocations = 100.times.map do |i|
        build_allocation(
          frequency: frequencies[i % 3],
          starts_at: 1.day.from_now.change(usec: 0) + i.minutes
        )
      end

      horizon = 3.months.from_now

      elapsed = Benchmark.measure {
        allocations.each do |alloc|
          WhittakerTech::Aeon::Projector.call(allocation_id: alloc.id, target_until: horizon)
        end
      }.real

      total = WhittakerTech::Aeon::Occurrence.count
      puts "  → Projected #{total} occurrences across 100 allocations in #{elapsed.round(3)}s"

      expect(elapsed).to be < 30.0
    end
  end

  describe "Range query over large dataset" do
    it "queries within_range over a 1-month window in under 50ms" do
      # Seed: 20 daily allocations, each projected 3 months
      allocations = 20.times.map do |i|
        build_allocation(
          frequency: :daily,
          starts_at: 1.day.from_now.change(usec: 0) + i.minutes
        )
      end

      horizon = 3.months.from_now
      allocations.each do |alloc|
        WhittakerTech::Aeon::Projector.call(allocation_id: alloc.id, target_until: horizon)
      end

      total = WhittakerTech::Aeon::Occurrence.count
      query_start = 1.month.from_now
      query_end = 2.months.from_now
      range = "[#{query_start.iso8601},#{query_end.iso8601})"

      # Warm up PG planner cache
      WhittakerTech::Aeon::Occurrence.within_range(range).to_a

      elapsed = Benchmark.measure {
        results = WhittakerTech::Aeon::Occurrence.within_range(range).to_a
        puts "  → Found #{results.size} occurrences out of #{total} total in range query"
      }.real

      puts "  → Range query completed in #{(elapsed * 1000).round(1)}ms"
      expect(elapsed).to be < 0.05
    end
  end

  describe "Fork with invalidation" do
    it "forks a 365-occurrence allocation at midpoint in under 1 second" do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.year

      WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)

      before_count = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count
      pivot = allocation.starts_at + 6.months

      elapsed = Benchmark.measure {
        WhittakerTech::Aeon::Forker.call(
          allocation_id: allocation.id,
          pivot: pivot,
          duration_seconds: 7200
        )
      }.real

      invalidated = WhittakerTech::Aeon::Occurrence
                      .where(allocation_id: allocation.id)
                      .where.not(invalidated_at: nil)
                      .count

      puts "  → Forked #{before_count} occurrences (#{invalidated} invalidated) in #{elapsed.round(3)}s"
      expect(elapsed).to be < 1.0
    end
  end

  describe "Idempotent re-projection" do
    it "re-projects to the same horizon in under 200ms" do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.year

      WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)
      count_before = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count

      elapsed = Benchmark.measure {
        WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)
      }.real

      count_after = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count
      puts "  → Re-projection (#{count_after} rows, no change) in #{elapsed.round(3)}s"

      expect(count_after).to eq(count_before)
      expect(elapsed).to be < 0.2
    end
  end

  describe "EXPLAIN verification" do
    it "uses GiST index for within_range queries" do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.month

      WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)

      range = "[#{1.week.from_now.iso8601},#{2.weeks.from_now.iso8601})"
      sql = WhittakerTech::Aeon::Occurrence.within_range(range).to_sql
      explain = ActiveRecord::Base.connection.execute("EXPLAIN #{sql}").map { |r| r["QUERY PLAN"] }.join("\n")

      puts "  → EXPLAIN plan:\n#{explain.lines.map { |l| "    #{l}" }.join}"

      expect(explain).to match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan/i)
    end
  end
end
