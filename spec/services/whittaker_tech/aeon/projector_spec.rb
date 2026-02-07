# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Aeon::Projector do
  let(:now) { Time.current.change(usec: 0) }
  let(:start) { now - 7.days }

  describe 'temporal kind expansion' do
    it 'projects a single occurrence for an instant allocation' do
      alloc = create(:allocation, :instant, starts_at: now, valid_from: now, projected_until: now)

      described_class.call(allocation_id: alloc.id, target_until: now + 1.day)

      occs = alloc.occurrences.reload
      expect(occs.size).to eq(1)
      expect(occs.first.starts_at).to eq(occs.first.ends_at)
    end

    it 'projects a single occurrence for a span allocation' do
      alloc = create(:allocation, :span, starts_at: now, duration_seconds: 7200,
                                         valid_from: now, projected_until: now)

      described_class.call(allocation_id: alloc.id, target_until: now + 1.day)

      occs = alloc.occurrences.reload
      expect(occs.size).to eq(1)
      expect(occs.first.ends_at - occs.first.starts_at).to eq(7200)
    end

    it 'projects daily occurrences for a schedule allocation' do
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)

      described_class.call(allocation_id: alloc.id, target_until: now)

      occs = alloc.occurrences.reload
      expect(occs.size).to be >= 7
      expect(occs.pluck(:starts_at).sort).to eq(occs.pluck(:starts_at).sort.uniq)
    end
  end

  describe 'idempotency' do
    it 'produces no duplicates when run twice with the same target' do
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)
      target = now + 7.days

      described_class.call(allocation_id: alloc.id, target_until: target)
      count_after_first = alloc.occurrences.count

      described_class.call(allocation_id: alloc.id, target_until: target)
      count_after_second = alloc.occurrences.count

      expect(count_after_second).to eq(count_after_first)
    end

    it 'produces no duplicates when run twice with an extended target' do
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)

      described_class.call(allocation_id: alloc.id, target_until: now)
      first_ids = alloc.occurrences.pluck(:id).sort

      described_class.call(allocation_id: alloc.id, target_until: now + 7.days)
      all_ids = alloc.occurrences.reload.pluck(:id).sort

      expect(all_ids).to include(*first_ids)
      expect(all_ids.size).to be > first_ids.size
    end
  end

  describe 'horizon enforcement' do
    it 'caps projection at max_projection_window' do
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)
      absurd_target = now + 100.years

      described_class.call(allocation_id: alloc.id, target_until: absurd_target)
      alloc.reload

      max_allowed = start + WhittakerTech::Aeon.configuration.max_projection_window
      expect(alloc.projected_until).to be <= max_allowed
    end

    it 'caps projection at valid_to for closed allocations' do
      close_at = now + 3.days
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)
      alloc.update_columns(valid_to: close_at)

      described_class.call(allocation_id: alloc.id, target_until: now + 30.days)
      alloc.reload

      expect(alloc.projected_until).to be <= close_at
    end

    it 'advances projected_until monotonically' do
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)

      described_class.call(allocation_id: alloc.id, target_until: now)
      first_frontier = alloc.reload.projected_until

      described_class.call(allocation_id: alloc.id, target_until: now + 7.days)
      second_frontier = alloc.reload.projected_until

      expect(second_frontier).to be >= first_frontier
    end

    it 'is a no-op when already projected past the target' do
      alloc = create(:allocation, starts_at: start, valid_from: start, projected_until: start)

      described_class.call(allocation_id: alloc.id, target_until: now + 7.days)
      frontier = alloc.reload.projected_until
      count = alloc.occurrences.count

      described_class.call(allocation_id: alloc.id, target_until: now)
      expect(alloc.reload.projected_until).to eq(frontier)
      expect(alloc.occurrences.count).to eq(count)
    end
  end

  describe 'upsert correctness' do
    it 'stores consistent time_range, starts_at, and ends_at' do
      alloc = create(:allocation, :projected)

      alloc.occurrences.each do |occ|
        lower = ActiveRecord::Base.connection.select_value(
          "SELECT lower(time_range) FROM #{occ.class.table_name} WHERE id = '#{occ.id}'"
        )
        expect(lower).to be_within(1.second).of(occ.starts_at)
      end
    end

    it 'sets a projection_fingerprint on every occurrence' do
      alloc = create(:allocation, :projected)

      alloc.occurrences.each do |occ|
        expect(occ.projection_fingerprint).to be_present
        expect(occ.projection_fingerprint.length).to eq(64) # SHA256 hex
      end
    end
  end
end
