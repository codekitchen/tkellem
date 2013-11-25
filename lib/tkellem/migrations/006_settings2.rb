class Settings2 < ActiveRecord::Migration
  def self.up
    Tkellem::Setting.make_new('private_key_file', nil)
    Tkellem::Setting.make_new('cert_chain_file', nil)
  end
end
