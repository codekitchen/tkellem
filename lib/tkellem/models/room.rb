class Room < ActiveRecord::Base
  # these aren't persisted, we just grab them on connect
  attr_accessor :topic, :topic_setter, :topic_time

  belongs_to :network_user
end
