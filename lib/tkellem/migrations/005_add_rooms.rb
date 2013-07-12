class AddRooms < ActiveRecord::Migration
  def self.up
    create_table 'rooms' do |t|
      t.integer :network_user_id
      t.string  :name
    end
  end
end


