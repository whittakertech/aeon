# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Aeon::Disposer do
  let(:now) { Time.current.change(usec: 0) }
  let(:start) { now - 14.days }

  # Creates an allocation, projects it, forks at the given pivot to generate
  # invalidated occurrences, then returns the old (forked) allocation.
  def create_forked_allocation(disposal_policy: nil)
    alloc = create(:allocation, :projected, starts_at: start, valid_from: start, projected_until: start)
    alloc.update_columns(disposal_policy: disposal_policy) if disposal_policy
    WhittakerTech::Aeon::Forker.call(allocation_id: alloc.id, pivot: alloc.valid_from, duration_seconds: 1800)
    alloc.reload
  end

  describe 'windowed policy' do
    it 'purges invalidated occurrences older than the retention window' do
      alloc = create_forked_allocation
      # Simulate aged invalidation
      alloc.occurrences.invalidated.update_all(invalidated_at: 90.days.ago)

      purged = described_class.call
      expect(purged).to be > 0
      expect(alloc.occurrences.where.not(purged_at: nil).count).to eq(purged)
    end

    it 'preserves invalidated occurrences within the retention window' do
      alloc = create_forked_allocation
      # invalidated_at is recent (set by Forker moments ago) — within 60-day window

      purged = described_class.call
      expect(purged).to eq(0)
      expect(alloc.occurrences.invalidated.where(purged_at: nil).count).to be > 0
    end
  end

  describe 'ephemeral policy' do
    it 'purges invalidated occurrences immediately regardless of age' do
      alloc = create_forked_allocation(disposal_policy: 'ephemeral')
      invalidated_count = alloc.occurrences.invalidated.count
      expect(invalidated_count).to be > 0

      purged = described_class.call
      expect(purged).to eq(invalidated_count)
      expect(alloc.occurrences.invalidated.where(purged_at: nil).count).to eq(0)
    end
  end

  describe 'historical policy' do
    it 'never auto-purges invalidated occurrences' do
      alloc = create_forked_allocation(disposal_policy: 'historical')
      alloc.occurrences.invalidated.update_all(invalidated_at: 1.year.ago)

      purged = described_class.call
      expect(purged).to eq(0)
      expect(alloc.occurrences.invalidated.where(purged_at: nil).count).to be > 0
    end
  end

  describe 'permanent policy' do
    it 'never auto-purges invalidated occurrences' do
      alloc = create_forked_allocation(disposal_policy: 'permanent')
      alloc.occurrences.invalidated.update_all(invalidated_at: 1.year.ago)

      purged = described_class.call
      expect(purged).to eq(0)
      expect(alloc.occurrences.invalidated.where(purged_at: nil).count).to be > 0
    end
  end

  describe 'per-allocation override' do
    it 'respects allocation-level policy over global default' do
      # Global default is :windowed. Create one ephemeral and one windowed.
      ephemeral_alloc = create_forked_allocation(disposal_policy: 'ephemeral')
      windowed_alloc = create_forked_allocation

      ephemeral_count = ephemeral_alloc.occurrences.invalidated.count
      expect(ephemeral_count).to be > 0

      purged = described_class.call
      # Ephemeral should be purged; windowed (recent) should not
      expect(ephemeral_alloc.occurrences.invalidated.where(purged_at: nil).count).to eq(0)
      expect(windowed_alloc.occurrences.invalidated.where(purged_at: nil).count).to be > 0
    end
  end

  describe 'global fallback' do
    it 'treats NULL disposal_policy as the global default' do
      alloc = create_forked_allocation
      expect(alloc.disposal_policy).to be_nil
      alloc.occurrences.invalidated.update_all(invalidated_at: 90.days.ago)

      purged = described_class.call
      expect(purged).to be > 0
    end
  end

  describe 'batch size limiting' do
    it 'purges at most batch_size rows per pass' do
      alloc = create_forked_allocation(disposal_policy: 'ephemeral')
      invalidated_count = alloc.occurrences.invalidated.count
      expect(invalidated_count).to be > 1

      purged = described_class.call(batch_size: 1)
      expect(purged).to eq(1)
    end
  end

  describe 'already-purged rows' do
    it 'does not re-process rows with purged_at already set' do
      alloc = create_forked_allocation(disposal_policy: 'ephemeral')
      alloc.occurrences.invalidated.update_all(purged_at: 1.day.ago)

      purged = described_class.call
      expect(purged).to eq(0)
    end
  end

  describe 'active rows' do
    it 'never touches non-invalidated occurrences' do
      alloc = create(:allocation, :projected, starts_at: start, valid_from: start, projected_until: start)
      active_count = alloc.occurrences.active.count
      expect(active_count).to be > 0

      described_class.call
      expect(alloc.occurrences.active.count).to eq(active_count)
      expect(alloc.occurrences.where.not(purged_at: nil).count).to eq(0)
    end
  end

  describe 'return value' do
    it 'returns the total integer count of purged rows' do
      alloc = create_forked_allocation(disposal_policy: 'ephemeral')
      expected = alloc.occurrences.invalidated.count

      result = described_class.call
      expect(result).to be_an(Integer)
      expect(result).to eq(expected)
    end
  end
end
