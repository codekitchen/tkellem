class AddBacklogPositions < ActiveRecord::Migration
  def self.up
    create_table 'backlog_positions' do |t|
      t.integer :network_user_id
      t.string  :context_name
      t.string  :device_name
      t.integer :position, :default => 0
    end
  end
end

