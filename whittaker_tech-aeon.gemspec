# frozen_string_literal: true

require_relative 'lib/whittaker_tech/aeon/version'

Gem::Specification.new do |spec|
  spec.name        = 'whittaker_tech-aeon'
  spec.version     = WhittakerTech::Aeon::VERSION
  spec.authors     = ['Lee Whittaker']
  spec.email       = ['lee@whittaker.tech']
  spec.homepage    = 'https://github.com/whittakertech/aeon'
  spec.summary     = 'Temporal physics engine for Rails'
  spec.description = 'A Rails engine that projects immutable temporal laws (Allocations) into ' \
                     'materialized Occurrences while preserving historical integrity through ' \
                     'forward-only timeline forking.'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md', 'CHANGELOG.md']
  end

  spec.required_ruby_version = '>= 3.1'

  spec.add_dependency 'ice_cube', '~> 0.16'
  spec.add_dependency 'pg', '~> 1.1'
  spec.add_dependency 'rails', '~> 7.1.0'
end
