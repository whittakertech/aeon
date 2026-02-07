# frozen_string_literal: true

module WhittakerTech
  module Aeon
    module Generators
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path('templates', __dir__)

        desc 'Copies the Aeon initializer and migrations into your application.'

        def copy_initializer
          template 'initializer.rb', 'config/initializers/aeon.rb'
        end

        def copy_migrations
          rake 'whittaker_tech_aeon:install:migrations'
        end

        def show_next_steps
          say ''
          say 'Aeon installed successfully!', :green
          say ''
          say 'Next steps:'
          say '  1. Edit config/initializers/aeon.rb to customize settings'
          say '  2. Run `rails db:migrate` to create the wt_aeon schema and tables'
          say '  3. Include WhittakerTech::Aeon::Schedulable in your host models'
          say ''
        end
      end
    end
  end
end
