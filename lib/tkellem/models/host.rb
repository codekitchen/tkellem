module Tkellem

class Host < ActiveRecord::Base
  belongs_to :network

  def to_s
    "#{ssl ? 'ircs' : 'irc'}://#{address}:#{port}"
  end
end

end
