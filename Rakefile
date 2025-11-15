require "bundler/setup"
require "rake"

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
  puts "RSpec not available; skipping specs"
end

task :environment do
  require_relative "config/environment"
end

# Placeholder for future DB tasks
namespace :db do
  desc "Create test database"
  task :create do
    puts "Test database ready (SQLite in-memory)"
  end
end
