require "rails_helper"

RSpec.describe WhittakerTech::Aeon::Forker do
  let(:now) { Time.current.change(usec: 0) }
  let(:start) { now - 14.days }
  let(:alloc) { create(:allocation, :projected, starts_at: start, valid_from: start, projected_until: start) }

  describe "fork future" do
    let(:pivot) { now }
    let!(:past_ids) do
      alloc.occurrences.where("starts_at < ?", pivot).pluck(:id).sort
    end
    let!(:future_count) do
      alloc.occurrences.where("starts_at >= ?", pivot).count
    end
    let(:new_alloc) do
      described_class.call(allocation_id: alloc.id, pivot: pivot, duration_seconds: 7200)
    end

    it "closes the old allocation at the pivot" do
      new_alloc
      expect(alloc.reload.valid_to).to eq(pivot)
    end

    it "creates a successor with fork lineage" do
      expect(new_alloc.supersedes_allocation_id).to eq(alloc.id)
      expect(new_alloc.valid_from).to eq(pivot)
      expect(new_alloc.valid_to).to be_nil
    end

    it "inherits fields and applies overrides" do
      expect(new_alloc.duration_seconds).to eq(7200)
      expect(new_alloc.schedulable_id).to eq(alloc.schedulable_id)
      expect(new_alloc.temporal_kind).to eq(alloc.temporal_kind)
      expect(new_alloc.timezone).to eq(alloc.timezone)
    end

    it "leaves past occurrences untouched" do
      new_alloc
      still_active = alloc.occurrences
                          .where(id: past_ids)
                          .where(invalidated_at: nil)
                          .pluck(:id).sort

      expect(still_active).to eq(past_ids)
    end

    it "invalidates future occurrences with set-based SQL" do
      new_alloc
      invalidated = alloc.occurrences
                         .where("starts_at >= ?", pivot)
                         .where.not(invalidated_at: nil)
                         .count

      expect(invalidated).to eq(future_count)
    end

    it "stamps invalidated_by_allocation_id on invalidated occurrences" do
      new_alloc
      alloc.occurrences.where.not(invalidated_at: nil).each do |occ|
        expect(occ.invalidated_by_allocation_id).to eq(new_alloc.id)
      end
    end

    it "projects occurrences for the new allocation" do
      expect(new_alloc.occurrences.count).to be > 0
      new_alloc.occurrences.each do |occ|
        expect(occ.ends_at - occ.starts_at).to eq(7200)
      end
    end

    it "inherits disposal_policy" do
      alloc.update_columns(disposal_policy: "permanent")
      result = described_class.call(allocation_id: alloc.id, pivot: pivot)
      expect(result.disposal_policy).to eq("permanent")
    end
  end

  describe "fork all" do
    it "invalidates every occurrence including the earliest" do
      new_alloc = described_class.call(
        allocation_id: alloc.id,
        pivot: alloc.valid_from,
        duration_seconds: 1800
      )

      remaining = alloc.occurrences.where(invalidated_at: nil).count
      expect(remaining).to eq(0)
      expect(new_alloc.occurrences.count).to be > 0
    end
  end

  describe "validation" do
    it "rejects a pivot before valid_from" do
      expect {
        described_class.call(allocation_id: alloc.id, pivot: alloc.valid_from - 1.day)
      }.to raise_error(ArgumentError, /before allocation valid_from/)
    end

    it "rejects forking an already-closed allocation" do
      alloc.update_columns(valid_to: now)
      expect {
        described_class.call(allocation_id: alloc.id, pivot: now + 1.day)
      }.to raise_error(ArgumentError, /already closed/)
    end

    it "raises RecordNotFound for nonexistent allocation" do
      expect {
        described_class.call(allocation_id: SecureRandom.uuid, pivot: now)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
