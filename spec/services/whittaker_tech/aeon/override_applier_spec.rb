require "rails_helper"

RSpec.describe WhittakerTech::Aeon::OverrideApplier do
  let(:alloc) { create(:allocation, :projected) }
  let(:occurrence) { alloc.occurrences.first }

  describe "cancellation" do
    it "creates a canceled override" do
      override = described_class.call(occurrence_id: occurrence.id, canceled: true)

      expect(override).to be_persisted
      expect(override.canceled).to be true
      expect(override.replacement_time_range).to be_nil
      expect(occurrence.reload.override).to eq(override)
    end
  end

  describe "rescheduling" do
    it "creates an override with a replacement time range" do
      new_start = occurrence.starts_at + 2.hours
      new_end = new_start + 3600
      range = "[#{new_start.iso8601},#{new_end.iso8601})"

      override = described_class.call(
        occurrence_id: occurrence.id,
        replacement_time_range: range
      )

      expect(override).to be_persisted
      expect(override.canceled).to be false
      expect(override.replacement_time_range).to be_present
    end
  end

  describe "constraints" do
    it "enforces one override per occurrence via DB unique index" do
      described_class.call(occurrence_id: occurrence.id, canceled: true)

      expect {
        described_class.call(occurrence_id: occurrence.id, canceled: true)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects overriding an invalidated occurrence" do
      occurrence.update_columns(
        invalidated_at: Time.current,
        invalidated_by_allocation_id: alloc.id
      )

      expect {
        described_class.call(occurrence_id: occurrence.id, canceled: true)
      }.to raise_error(ArgumentError, /invalidated/)
    end

    it "rejects a no-action override" do
      expect {
        described_class.call(occurrence_id: occurrence.id)
      }.to raise_error(ArgumentError, /canceled.*replacement_time_range/)
    end

    it "raises RecordNotFound for nonexistent occurrence" do
      expect {
        described_class.call(occurrence_id: SecureRandom.uuid, canceled: true)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
