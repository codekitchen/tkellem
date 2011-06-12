module Tkellem

class NetworkUser < ActiveRecord::Base
  belongs_to :network
  belongs_to :user

  def nick
    read_attribute(:nick) || user.name
  end
end

end
