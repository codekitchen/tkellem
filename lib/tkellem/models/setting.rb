module Tkellem

class Setting < Sequel::Model
  def self.get(setting_name)
    setting = first(:conditions => { :name => setting_name })
    setting.try(:value)
  end

  def self.set(setting_name, new_value)
    setting = first(:conditions => { :name => setting_name })
    setting.try(:update_attributes, :value => new_value.to_s, :unchanged => false)
    setting
  end

  def self.make_new(setting_name, default_value)
    create!(:name => setting_name, :value => default_value.to_s, :unchanged => true)
  end

  def to_s
    "#{name}: #{value}"
  end
end

end
