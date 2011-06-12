module Tkellem

class Network < ActiveRecord::Base
  has_many :hosts, :class_name => 'Tkellem::Host'
end

end
