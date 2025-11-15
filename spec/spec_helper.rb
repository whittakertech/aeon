ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rspec/rails"

Dir[File.expand_path("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = "#{__dir__}/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
