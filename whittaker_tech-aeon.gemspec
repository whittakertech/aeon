Gem::Specification.new do |spec|
  spec.name          = "whittaker_tech-aeon"
  spec.version       = "0.1.0"
  spec.authors       = ["WhittakerTech"]
  spec.email         = ["lee@whittakertech.com"]
  spec.summary       = "Aeon: Temporal Logic for WhittakerTech"
  spec.description   = "Comprehensive scheduling, recurrence, and temporal caching engine for Rails applications"
  spec.homepage      = "https://github.com/whittakertech/aeon"
  spec.license       = "MIT"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "db/**/*", "spec/**/*", "README.md", "MIT-LICENSE", "Rakefile", "gemspec"]
  spec.test_files = Dir["spec/**/*"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "ice_cube", "~> 0.17"
  spec.add_dependency "redis", "~> 5.0"

  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.2"
  spec.add_development_dependency "pg", "~> 1.5"
end
