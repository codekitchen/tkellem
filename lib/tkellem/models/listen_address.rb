module Tkellem

class ListenAddress < ActiveRecord::Base
  validates_uniqueness_of :port, :scope => [:address]
  validates_presence_of :address, :port

  def to_s
    "#{address}:#{port} (ssl=#{!!ssl.inspect})"
  end
end

end
