class AtConnectColumns < ActiveRecord::Migration
  def self.up
    add_column 'networks', 'at_connect', 'text'
    add_column 'network_users', 'at_connect', 'text'
  end
end

