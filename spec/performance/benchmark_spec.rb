# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Performance', :performance do
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
           timezone: 'UTC',
           rrule: schedule.to_hash,
           valid_from: starts_at,
           projected_until: starts_at)
  end

  describe 'Projection throughput' do
    it 'projects a daily schedule over 1 year in under 1 second' do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.year

      elapsed = Benchmark.measure do
        WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)
      end.real

      count = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count

      expect(count).to be >= 365
      expect(elapsed).to be < 1.0
    end
  end

  describe 'Batch projection at scale' do
    it 'projects 100 varied allocations in under 30 seconds' do
      frequencies = %i[daily weekly hourly]
      allocations = Array.new(100) do |i|
        build_allocation(
          frequency: frequencies[i % 3],
          starts_at: 1.day.from_now.change(usec: 0) + i.minutes
        )
      end

      horizon = 3.months.from_now

      elapsed = Benchmark.measure do
        allocations.each do |alloc|
          WhittakerTech::Aeon::Projector.call(allocation_id: alloc.id, target_until: horizon)
        end
      end.real

      WhittakerTech::Aeon::Occurrence.count

      expect(elapsed).to be < 30.0
    end
  end

  describe 'Range query over large dataset' do
    it 'queries within_range over a 1-month window in under 50ms' do
      # Seed: 20 daily allocations, each projected 3 months
      allocations = Array.new(20) do |i|
        build_allocation(
          frequency: :daily,
          starts_at: 1.day.from_now.change(usec: 0) + i.minutes
        )
      end

      horizon = 3.months.from_now
      allocations.each do |alloc|
        WhittakerTech::Aeon::Projector.call(allocation_id: alloc.id, target_until: horizon)
      end

      WhittakerTech::Aeon::Occurrence.count
      query_start = 1.month.from_now
      query_end = 2.months.from_now
      range = "[#{query_start.iso8601},#{query_end.iso8601})"

      # Warm up PG planner cache
      WhittakerTech::Aeon::Occurrence.within_range(range).to_a

      elapsed = Benchmark.measure do
        WhittakerTech::Aeon::Occurrence.within_range(range).to_a
      end.real

      expect(elapsed).to be < 0.05
    end
  end

  describe 'Fork with invalidation' do
    it 'forks a 365-occurrence allocation at midpoint in under 1 second' do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.year

      WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)

      WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count
      pivot = allocation.starts_at + 6.months

      elapsed = Benchmark.measure do
        WhittakerTech::Aeon::Forker.call(
          allocation_id: allocation.id,
          pivot: pivot,
          duration_seconds: 7200
        )
      end.real

      WhittakerTech::Aeon::Occurrence
        .where(allocation_id: allocation.id)
        .where.not(invalidated_at: nil)
        .count

      expect(elapsed).to be < 1.0
    end
  end

  describe 'Idempotent re-projection' do
    it 're-projects to the same horizon in under 200ms' do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.year

      WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)
      count_before = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count

      elapsed = Benchmark.measure do
        WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)
      end.real

      count_after = WhittakerTech::Aeon::Occurrence.where(allocation_id: allocation.id).count

      expect(count_after).to eq(count_before)
      expect(elapsed).to be < 0.2
    end
  end

  describe 'EXPLAIN verification' do
    it 'uses GiST index for within_range queries' do
      allocation = build_allocation(frequency: :daily)
      horizon = allocation.starts_at + 1.month

      WhittakerTech::Aeon::Projector.call(allocation_id: allocation.id, target_until: horizon)

      range = "[#{1.week.from_now.iso8601},#{2.weeks.from_now.iso8601})"
      sql = WhittakerTech::Aeon::Occurrence.within_range(range).to_sql

      conn = ActiveRecord::Base.connection
      conn.execute('SET enable_seqscan = off')
      explain = conn.execute("EXPLAIN #{sql}").pluck('QUERY PLAN').join("\n")
      conn.execute('RESET enable_seqscan')

      expect(explain).to match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan/i)
    end
  end
end
