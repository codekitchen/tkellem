module Tkellem

class Network < ActiveRecord::Base
  has_many :hosts, :dependent => :destroy
  has_many :network_users, :dependent => :destroy
  # networks either belong to a specific user, or they are public and any user
  # can join them.
  belongs_to :user

  serialize :at_connect, Array

  def at_connect
    read_attribute(:at_connect) || []
  end

  def public?
    !user
  end
end

end
