module Tkellem

class Network < Sequel::Model
  plugin :nested_attributes
  plugin :validation_class_methods
  plugin :serialization

  one_to_many :hosts, :dependent => :destroy
  nested_attributes :hosts

  one_to_many :network_users, :dependent => :destroy
  # networks either belong to a specific user, or they are public and any user
  # can join them.
  many_to_one :user

  validates_uniqueness_of :name, :scope => :user_id

  serialize_attributes :yaml, :at_connect

  def at_connect
    super || []
  end

  def public?
    !user
  end
end

end
