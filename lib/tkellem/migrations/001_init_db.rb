class InitDb < ActiveRecord::Migration
  def self.up
    create_table 'listen_addresses' do |t|
      t.string  'address', :null => false
      t.integer 'port', :null => false
      t.boolean 'ssl', :null => false, :default => false
    end

    create_table 'users' do |t|
      t.string 'username', :null => false
      t.string 'password'
      t.string 'role', :null => false, :default => 'user'
    end

    create_table 'networks' do |t|
      t.belongs_to 'user'
      t.string 'name', :null => false
    end

    create_table 'hosts' do |t|
      t.belongs_to 'network'
      t.string  'address', :null => false
      t.integer 'port', :null => false
      t.boolean 'ssl', :null => false, :default => false
    end

    create_table 'network_users' do |t|
      t.belongs_to 'user'
      t.belongs_to 'network'
      t.string 'nick'
    end
  end
end
