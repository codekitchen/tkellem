module Tkellem

class NetworkUser < ActiveRecord::Base
  belongs_to :network
  belongs_to :user

  serialize :at_connect, Array

  def nick
    read_attribute(:nick) || user.name
  end

  # we use the network's at_connect until it is modified and overwritten for
  # this specific network user
  def at_connect
    network.at_connect + (read_attribute(:at_connect) || [])
  end
end

end
