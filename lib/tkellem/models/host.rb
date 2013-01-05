module Tkellem

class Host < Sequel::Model
  many_to_one :network

  def to_s
    self.class.address_string(address, port, ssl)
  end

  def self.address_string(address, port, ssl)
    "#{ssl ? 'ircs' : 'irc'}://#{address}:#{port}"
  end
end

end
