module Tkellem

class NetworkUser < ActiveRecord::Base
  belongs_to :network
  belongs_to :user

  serialize :at_connect, Array

  def nick
    read_attribute(:nick) || user.name
  end

  def combined_at_connect
    network.at_connect + (at_connect || [])
  end
end

end
