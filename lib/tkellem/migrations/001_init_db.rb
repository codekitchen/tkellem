Sequel.migration do
  up do
    if self.table_exists?(:schema_migrations) && self[:schema_migrations].first(:version => '1')
      next
    end

    create_table 'listen_addresses' do
      primary_key :id
      String  'address', :null => false
      Integer 'port', :null => false
      boolean 'ssl', :null => false, :default => false
    end

    create_table 'users' do
      primary_key :id
      String 'username', :null => false
      String 'password'
      String 'role', :null => false, :default => 'user'
    end

    create_table 'networks' do
      primary_key :id
      foreign_key :user_id, :users
      String 'name', :null => false
    end

    create_table 'hosts' do
      primary_key :id
      foreign_key :network_id, :networks
      String  'address', :null => false
      Integer 'port', :null => false
      boolean 'ssl', :null => false, :default => false
    end

    create_table 'network_users' do
      primary_key :id
      foreign_key :user_id, :users
      foreign_key :network_id, :networks
      String 'nick'
    end
  end

  down do
    drop_table 'network_users'
    drop_table 'hosts'
    drop_table 'networks'
    drop_table 'users'
    drop_table 'listen_addresses'
  end
end
