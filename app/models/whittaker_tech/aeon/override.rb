module WhittakerTech
  module Aeon
    class Override < ApplicationRecord
      belongs_to :occurrence, inverse_of: :override
    end
  end
end
