module Tkellem

class Host < ActiveRecord::Base
  belongs_to :network

  def to_s
    self.class.address_string(address, port, ssl)
  end

  def self.address_string(address, port, ssl)
    "#{ssl ? 'ircs' : 'irc'}://#{address}:#{port}"
  end
end

end
