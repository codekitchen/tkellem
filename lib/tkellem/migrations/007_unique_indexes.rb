class UniqueIndexes < ActiveRecord::Migration
  def self.up
    add_index :listen_addresses, [:address, :port, :ssl], unique: true
    add_index :users, :username, unique: true
    add_index :networks, [:name, :user_id], unique: true
    add_index :network_users, [:user_id, :network_id], unique: true
    if SQLite3::SQLITE_VERSION >= '3.8.0.0'
      execute("CREATE UNIQUE INDEX index_networks_on_name ON networks (name) WHERE user_id IS NULL")
    end
    add_index :settings, :name, unique: true
    add_index :backlog_positions, [:network_user_id, :context_name, :device_name], unique: true, name: 'index_backlog_positions'
    add_index :rooms, [:network_user_id, :name], unique: true
  end
end