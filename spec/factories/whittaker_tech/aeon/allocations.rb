# frozen_string_literal: true

FactoryBot.define do
  factory :allocation, class: 'WhittakerTech::Aeon::Allocation' do
    schedulable factory: :schedulable_host
    schedulable_label { 'time_slot' }
    temporal_kind { :schedule }
    starts_at { 7.days.ago.change(usec: 0) }
    duration_seconds { 3600 }
    timezone { 'UTC' }
    rrule { IceCube::Schedule.new(starts_at) { |s| s.add_recurrence_rule IceCube::Rule.daily }.to_hash }
    valid_from { starts_at }
    projected_until { starts_at }

    trait :instant do
      temporal_kind { :instant }
      duration_seconds { nil }
      timezone { nil }
      rrule { nil }
    end

    trait :span do
      temporal_kind { :span }
      rrule { nil }
    end

    trait :projected do
      transient do
        project_until { 14.days.from_now }
      end

      after(:create) do |alloc, ctx|
        WhittakerTech::Aeon::Projector.call(
          allocation_id: alloc.id,
          target_until: ctx.project_until
        )
        alloc.reload
      end
    end
  end

  factory :schedulable_host do
    name { "Host #{SecureRandom.hex(4)}" }
  end
end
