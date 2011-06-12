class InitDb < ActiveRecord::Migration
  def self.up
    create_table 'listen_addresses' do |t|
      t.string  'address'
      t.integer 'port'
      t.boolean 'ssl'
    end

    create_table 'networks' do |t|
      t.string 'name'
    end

    create_table 'hosts' do |t|
      t.belongs_to 'network'
      t.string  'address'
      t.integer 'port'
      t.boolean 'ssl'
    end

    create_table 'users' do |t|
      t.string 'username'
      t.string 'password'
    end

    create_table 'network_users' do |t|
      t.belongs_to 'user'
      t.belongs_to 'network'
      t.string 'nick'
    end
  end
end
