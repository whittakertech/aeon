# Minimal host model for testing Schedulable concern.
# Table is created once per test suite run.

class SchedulableHost < ApplicationRecord
  self.table_name = "schedulable_hosts"

  include WhittakerTech::Aeon::Schedulable
  schedule :time_slot
end

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS schedulable_hosts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name character varying,
        created_at timestamp(6) NOT NULL DEFAULT now(),
        updated_at timestamp(6) NOT NULL DEFAULT now()
      );
    SQL
  end
end
