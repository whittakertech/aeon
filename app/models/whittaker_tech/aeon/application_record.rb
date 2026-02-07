module WhittakerTech
  module Aeon
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
