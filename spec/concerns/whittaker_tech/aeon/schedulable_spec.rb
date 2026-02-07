# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Aeon::Schedulable do
  let(:now) { Time.current.change(usec: 0) }
  let(:start) { now - 7.days }
  let(:host) { SchedulableHost.create!(name: 'test-host') }

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

  describe 'associations' do
    it 'exposes the active allocation via the named has_one' do
      expect(host.time_slot).to eq(alloc)
    end

    it 'returns nil when no active allocation exists' do
      WhittakerTech::Aeon::Allocation.transaction do
        WhittakerTech::Aeon::Allocation.connection.execute("SET LOCAL aeon.bypass_guard = 'true'")
        alloc.update_columns(valid_to: now)
      end
      host.reload
      expect(host.time_slot).to be_nil
    end

    it 'exposes occurrences via has_many through' do
      host.ensure_projected!
      expect(host.time_slot_occurrences.count).to be > 0
    end
  end

  describe 'ensure_projected!' do
    it 'projects the active allocation to the configured buffer' do
      host.ensure_projected!
      alloc.reload

      expect(alloc.projected_until).to be > now
      expect(host.time_slot_occurrences.count).to be > 0
    end

    it 'accepts a custom window' do
      host.ensure_projected!(window: 30.days)
      alloc.reload

      expect(alloc.projected_until).to be >= (now + 29.days)
    end
  end

  describe 'fork_future' do
    before { host.ensure_projected! }

    it 'forks at the pivot and returns the new allocation' do
      pivot = now + 3.days
      new_alloc = host.fork_future(pivot: pivot, duration_seconds: 7200)

      expect(new_alloc).to be_persisted
      expect(new_alloc.duration_seconds).to eq(7200)
      expect(new_alloc.supersedes_allocation_id).to eq(alloc.id)

      host.reload
      expect(host.time_slot).to eq(new_alloc)
    end
  end

  describe 'fork_all' do
    before { host.ensure_projected! }

    it 'invalidates all old occurrences and projects new ones' do
      old_alloc_id = alloc.id
      new_alloc = host.fork_all(duration_seconds: 1800)

      remaining = WhittakerTech::Aeon::Occurrence
                  .where(allocation_id: old_alloc_id, invalidated_at: nil)
                  .count

      expect(remaining).to eq(0)
      expect(new_alloc.occurrences.count).to be > 0
    end
  end

  describe 'override_occurrence' do
    before { host.ensure_projected! }

    it 'cancels an occurrence by starts_at' do
      occ = host.time_slot_occurrences.order(
        Arel.sql("#{WhittakerTech::Aeon::Occurrence.table_name}.starts_at")
      ).first

      override = host.override_occurrence(starts_at: occ.starts_at, canceled: true)

      expect(override).to be_persisted
      expect(override.canceled).to be true
      expect(occ.reload.override).to eq(override)
    end
  end

  describe 'error handling' do
    it 'raises when no active allocation exists' do
      empty_host = SchedulableHost.create!(name: 'no-schedule')

      expect { empty_host.fork_future(pivot: now) }
        .to raise_error(ArgumentError, /no active time_slot/)
      expect { empty_host.fork_all }
        .to raise_error(ArgumentError, /no active time_slot/)
      expect { empty_host.override_occurrence(starts_at: now, canceled: true) }
        .to raise_error(ArgumentError, /no active time_slot/)
      expect { empty_host.ensure_projected! }
        .to raise_error(ArgumentError, /no active time_slot/)
    end
  end

  describe 'multi-label coexistence' do
    let(:multi_host) { MultiScheduleHost.create!(name: 'multi-host') }

    let!(:time_slot_alloc) do
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

    let!(:availability_alloc) do
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

    it 'allows two active allocations with different labels on the same schedulable' do
      expect(time_slot_alloc).to be_persisted
      expect(availability_alloc).to be_persisted
    end

    it 'scopes has_one by label so each returns the correct allocation' do
      expect(multi_host.time_slot).to eq(time_slot_alloc)
      expect(multi_host.availability).to eq(availability_alloc)
    end

    it 'scopes occurrences through the correct allocation' do
      WhittakerTech::Aeon::Projector.call(allocation_id: time_slot_alloc.id, target_until: 14.days.from_now)
      WhittakerTech::Aeon::Projector.call(allocation_id: availability_alloc.id, target_until: 14.days.from_now)

      ts_count = multi_host.time_slot_occurrences.count
      av_count = multi_host.availability_occurrences.count

      expect(ts_count).to be > av_count
    end
  end
end
