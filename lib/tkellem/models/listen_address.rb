module Tkellem

class ListenAddress < ActiveRecord::Base
  validates_uniqueness_of :port, :scope => [:address]
  validates_presence_of :address, :port

  def to_s
    "#{ssl ? 'ircs' : 'irc'}://#{address}:#{port}"
  end
end

end
