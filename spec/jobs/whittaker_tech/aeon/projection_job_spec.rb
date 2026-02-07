# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Aeon::ProjectionJob do
  let(:alloc) { create(:allocation) }

  it 'delegates to Projector with the parsed horizon' do
    target = 7.days.from_now
    described_class.perform_now(alloc.id, target.iso8601)
    alloc.reload

    expect(alloc.projected_until).to be > alloc.starts_at
    expect(alloc.occurrences.count).to be > 0
  end

  it 'is idempotent' do
    target = 7.days.from_now.iso8601

    described_class.perform_now(alloc.id, target)
    count = alloc.occurrences.count

    described_class.perform_now(alloc.id, target)
    expect(alloc.occurrences.count).to eq(count)
  end

  it 'queues to :aeon_projection' do
    expect(described_class.queue_name).to eq('aeon_projection')
  end
end
