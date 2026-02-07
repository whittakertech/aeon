# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Immutability guards' do
  describe WhittakerTech::Aeon::Allocation do
    let(:alloc) { create(:allocation) }

    WhittakerTech::Aeon::Allocation::TEMPORAL_FIELDS.each do |field|
      it "blocks mutation of #{field}" do
        new_value = case field
                    when 'temporal_kind' then 0
                    when 'starts_at', 'valid_from', 'valid_to', 'projected_until' then Time.current
                    when 'duration_seconds' then 9999
                    when 'timezone' then 'America/New_York'
                    when 'rrule' then { 'rule_type' => 'IceCube::MinutelyRule' }
                    when 'supersedes_allocation_id', 'schedulable_id' then SecureRandom.uuid
                    when 'schedulable_type' then 'SomeOtherModel'
                    end

        alloc.reload
        alloc.assign_attributes(field => new_value)
        # validate: false bypasses belongs_to validations so the before_update guard fires
        expect { alloc.save!(validate: false) }.to raise_error(ActiveRecord::ReadonlyAttributeError, /#{field}/)
      end
    end

    it 'allows updating metadata fields' do
      alloc.update!(disposal_policy: 'permanent')
      expect(alloc.reload.disposal_policy).to eq('permanent')
    end
  end

  describe WhittakerTech::Aeon::Occurrence do
    let(:alloc) { create(:allocation, :projected) }
    let(:occurrence) { alloc.occurrences.first }

    WhittakerTech::Aeon::Occurrence::COORDINATE_FIELDS.each do |field|
      it "blocks mutation of #{field}" do
        new_value = case field
                    when 'time_range' then "[#{Time.current.iso8601},#{1.hour.from_now.iso8601})"
                    when 'starts_at', 'ends_at' then Time.current
                    when 'allocation_id' then SecureRandom.uuid
                    end

        occurrence.reload
        occurrence.assign_attributes(field => new_value)
        # validate: false bypasses belongs_to validations so the before_update guard fires
        expect { occurrence.save!(validate: false) }.to raise_error(ActiveRecord::ReadonlyAttributeError, /#{field}/)
      end
    end

    it 'allows updating invalidation fields' do
      occurrence.update!(invalidated_at: Time.current, invalidated_by_allocation_id: alloc.id)
      expect(occurrence.reload.invalidated_at).to be_present
    end
  end
end
