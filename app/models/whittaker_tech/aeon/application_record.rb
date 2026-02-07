module WhittakerTech
  module Aeon
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = "wt_aeon."
    end
  end
end
