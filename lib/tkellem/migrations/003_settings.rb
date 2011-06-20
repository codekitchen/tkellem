class Settings < ActiveRecord::Migration
  def self.up
    create_table 'settings' do |t|
      t.string :name, :null => false
      t.string :value, :null => false
      t.boolean :unchanged, :null => false, :default => true
    end

    Tkellem::Setting.make_new('user_registration', 'closed')
    Tkellem::Setting.make_new('recaptcha_api_key', '')
    Tkellem::Setting.make_new('allow_user_networks', 'false')
  end
end
