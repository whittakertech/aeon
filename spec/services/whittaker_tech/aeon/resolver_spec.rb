# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Aeon::Resolver do
  let(:now) { Time.current.change(usec: 0) }
  let(:start) { now - 7.days }
  let(:host) { SchedulableHost.create!(name: 'resolver-host') }
  let(:window) { (now - 1.day)..(now + 7.days) }

  let!(:alloc) do
    schedule = IceCube::Schedule.new(start) { |s| s.add_recurrence_rule IceCube::Rule.daily }
    WhittakerTech::Aeon::Allocation.create!(
      schedulable: host,
      schedulable_label: 'time_slot',
      temporal_kind: :schedule,
      starts_at: start,
      duration_seconds: 3600,
      timezone: 'UTC',
      rrule: schedule.to_hash,
      valid_from: start,
      projected_until: start
    )
  end

  before do
    WhittakerTech::Aeon::Projector.call(allocation_id: alloc.id, target_until: now + 14.days)
  end

  describe 'basic resolution' do
    it 'returns occurrences in range as ResolvedOccurrence structs' do
      results = described_class.between(schedulable: host, range: window, label: :time_slot)

      expect(results).to all(be_a(WhittakerTech::Aeon::ResolvedOccurrence))
      expect(results).not_to be_empty
      results.each do |r|
        expect(r.allocation_id).to eq(alloc.id)
        expect(r.overridden).to be false
        expect(r.state).to eq('active')
        expect(r.schedulable_label).to eq('time_slot')
      end
    end
  end

  describe 'sort order' do
    it 'returns results sorted by starts_at ascending' do
      results = described_class.between(schedulable: host, range: window, label: :time_slot)

      starts = results.map(&:starts_at)
      expect(starts).to eq(starts.sort)
    end
  end

  describe 'frozen return value' do
    it 'returns a frozen array' do
      results = described_class.between(schedulable: host, range: window, label: :time_slot)

      expect(results).to be_frozen
    end
  end

  describe 'empty range' do
    it 'returns a frozen empty array when no matches exist' do
      far_future = (now + 100.years)..(now + 101.years)
      results = described_class.between(schedulable: host, range: far_future, label: :time_slot)

      expect(results).to eq([])
      expect(results).to be_frozen
    end
  end

  describe 'cancellation filtering' do
    it 'excludes canceled occurrences' do
      occ = alloc.occurrences.active.where(starts_at: window.begin..).order(:starts_at).first
      WhittakerTech::Aeon::OverrideApplier.call(occurrence_id: occ.id, canceled: true)

      results = described_class.between(schedulable: host, range: window, label: :time_slot)
      ids = results.map(&:occurrence_id)

      expect(ids).not_to include(occ.id)
    end
  end

  describe 'replacement substitution' do
    it 'uses replacement times and marks overridden: true' do
      occ = alloc.occurrences.active.where(starts_at: window.begin..).order(:starts_at).first
      new_start = occ.starts_at + 30.minutes
      new_end = occ.ends_at + 30.minutes
      replacement = "[#{new_start.iso8601},#{new_end.iso8601})"

      WhittakerTech::Aeon::OverrideApplier.call(occurrence_id: occ.id, replacement_time_range: replacement)

      results = described_class.between(schedulable: host, range: window, label: :time_slot)
      resolved = results.find { |r| r.occurrence_id == occ.id }

      expect(resolved).to be_present
      expect(resolved.overridden).to be true
      expect(resolved.starts_at).to be_within(1.second).of(new_start)
      expect(resolved.ends_at).to be_within(1.second).of(new_end)
    end
  end

  describe 'replacement out-of-window' do
    it 'excludes occurrences whose replacement shifts them outside the window' do
      occ = alloc.occurrences.active.where(starts_at: window.begin..).order(:starts_at).first
      far_start = window.end + 10.days
      far_end = far_start + 1.hour
      replacement = "[#{far_start.iso8601},#{far_end.iso8601})"

      WhittakerTech::Aeon::OverrideApplier.call(occurrence_id: occ.id, replacement_time_range: replacement)

      results = described_class.between(schedulable: host, range: window, label: :time_slot)
      ids = results.map(&:occurrence_id)

      expect(ids).not_to include(occ.id)
    end
  end

  describe 'invalidation filtering' do
    it 'does not return invalidated occurrences' do
      # Fork invalidates future occurrences from the old allocation
      pivot = now + 2.days
      new_alloc = WhittakerTech::Aeon::Forker.call(
        allocation_id: alloc.id, pivot: pivot, duration_seconds: 1800
      )

      results = described_class.between(schedulable: host, range: window, label: :time_slot)
      alloc_ids = results.map(&:allocation_id).uniq

      # Old allocation's invalidated occurrences should not appear
      invalidated_ids = WhittakerTech::Aeon::Occurrence
                        .where(allocation_id: alloc.id)
                        .where.not(invalidated_at: nil)
                        .pluck(:id)

      result_ids = results.map(&:occurrence_id)
      invalidated_ids.each { |iid| expect(result_ids).not_to include(iid) }

      # New allocation's occurrences should appear
      expect(alloc_ids).to include(new_alloc.id)
    end
  end

  describe 'fork correctness' do
    it 'includes surviving pre-fork and new post-fork occurrences' do
      pivot = now + 2.days
      new_alloc = WhittakerTech::Aeon::Forker.call(
        allocation_id: alloc.id, pivot: pivot, duration_seconds: 1800
      )

      results = described_class.between(schedulable: host, range: window, label: :time_slot)
      alloc_ids = results.map(&:allocation_id).uniq

      # Should include both old (surviving) and new allocation occurrences
      surviving_old = WhittakerTech::Aeon::Occurrence.active
                                                     .where(allocation_id: alloc.id)
                                                     .count
      expect(alloc_ids).to include(alloc.id) if surviving_old > 0
      expect(alloc_ids).to include(new_alloc.id)
    end
  end

  describe 'multi-label resolution' do
    let(:multi_host) { MultiScheduleHost.create!(name: 'multi-resolver') }

    let!(:ts_alloc) do
      schedule = IceCube::Schedule.new(start) { |s| s.add_recurrence_rule IceCube::Rule.daily }
      WhittakerTech::Aeon::Allocation.create!(
        schedulable: multi_host,
        schedulable_label: 'time_slot',
        temporal_kind: :schedule,
        starts_at: start,
        duration_seconds: 3600,
        timezone: 'UTC',
        rrule: schedule.to_hash,
        valid_from: start,
        projected_until: start
      )
    end

    let!(:av_alloc) do
      schedule = IceCube::Schedule.new(start) { |s| s.add_recurrence_rule IceCube::Rule.weekly }
      WhittakerTech::Aeon::Allocation.create!(
        schedulable: multi_host,
        schedulable_label: 'availability',
        temporal_kind: :schedule,
        starts_at: start,
        duration_seconds: 7200,
        timezone: 'UTC',
        rrule: schedule.to_hash,
        valid_from: start,
        projected_until: start
      )
    end

    before do
      WhittakerTech::Aeon::Projector.call(allocation_id: ts_alloc.id, target_until: now + 14.days)
      WhittakerTech::Aeon::Projector.call(allocation_id: av_alloc.id, target_until: now + 14.days)
    end

    it 'returns all labels when label is nil' do
      results = described_class.between(schedulable: multi_host, range: window)
      labels = results.map(&:schedulable_label).uniq

      expect(labels).to contain_exactly('time_slot', 'availability')
    end

    it 'returns only the named label when specified' do
      results = described_class.between(schedulable: multi_host, range: window, label: :availability)
      labels = results.map(&:schedulable_label).uniq

      expect(labels).to eq(['availability'])
    end
  end

  describe 'closed allocation in range' do
    it 'includes surviving occurrences from a closed allocation' do
      # Fork at a future point — old allocation gets closed but pre-pivot occurrences survive
      pivot = now + 3.days
      WhittakerTech::Aeon::Forker.call(allocation_id: alloc.id, pivot: pivot, duration_seconds: 1800)

      # Query a window that includes pre-pivot time
      pre_pivot_window = (now - 1.day)..pivot
      results = described_class.between(schedulable: host, range: pre_pivot_window, label: :time_slot)

      # Should include old allocation's surviving (pre-pivot) occurrences
      old_alloc_results = results.select { |r| r.allocation_id == alloc.id }
      expect(old_alloc_results).not_to be_empty
    end
  end

  describe 'DSL verb delegation' do
    it 'host.resolve_time_slot delegates to Resolver with correct label' do
      results = host.resolve_time_slot(range: window)

      expect(results).to all(be_a(WhittakerTech::Aeon::ResolvedOccurrence))
      expect(results).to be_frozen
      expect(results.map(&:schedulable_label).uniq).to eq(['time_slot'])
    end
  end
end
