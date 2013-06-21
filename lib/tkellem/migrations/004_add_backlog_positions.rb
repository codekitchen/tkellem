Sequel.migration do
  up do
    create_table 'backlog_positions' do
      primary_key :id
      foreign_key :user_id, :users
      foreign_key :network_id, :networks
      String :device_name
    end
  end

  down do
    drop_table 'backlog_positions'
  end
end
