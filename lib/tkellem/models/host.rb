module Tkellem

class Host < ActiveRecord::Base
  belongs_to :network
end

end
