Sequel.migration do
  up do
    if self.table_exists?(:schema_migrations) && self[:schema_migrations].first(:version => '2')
      next
    end

    alter_table 'networks' do
      add_column 'at_connect', String, :text => true
    end
    alter_table 'network_users' do
      add_column 'at_connect', String, :text => true
    end
  end

  down do
    alter_table 'network_users' do
      drop_column 'at_connect'
    end
    alter_table 'networks' do
      drop_column 'at_connect'
    end
  end
end

