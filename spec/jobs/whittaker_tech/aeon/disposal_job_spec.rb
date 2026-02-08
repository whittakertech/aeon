# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Aeon::DisposalJob do
  it 'delegates to Disposer.call' do
    expect(WhittakerTech::Aeon::Disposer).to receive(:call).and_return(0)
    described_class.perform_now
  end

  it 'queues to :aeon_disposal' do
    expect(described_class.queue_name).to eq('aeon_disposal')
  end
end
