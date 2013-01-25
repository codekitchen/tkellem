module Tkellem

class NetworkUser < Sequel::Model
  plugin :serialization

  many_to_one :network
  many_to_one :user

  serialize_attributes :yaml, :at_connect

  def at_connect
    super || []
  end

  def nick
    super || user.name
  end

  def combined_at_connect
    network.at_connect + at_connect
  end

  def after_create
    super
    $tkellem_server.try(:after_create, self)
  end

  def after_destroy
    super
    $tkellem_server.try(:after_destroy, self)
  end
end

end
