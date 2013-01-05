Sequel.migration do
  up do
    if self.table_exists?(:schema_migrations) && self[:schema_migrations].first(:version => '3')
      next
    end

    create_table 'settings' do
      primary_key :id
      String :name, :null => false
      String :value, :null => false
      boolean :unchanged, :null => false, :default => true
    end

    self[:settings].insert(:name => 'user_registration', :value => 'closed')
    self[:settings].insert(:name => 'recaptcha_api_key', :value => '')
    self[:settings].insert(:name => 'allow_user_networks', :value =>  'false')
  end

  down do
    drop_table 'settings'
  end
end
