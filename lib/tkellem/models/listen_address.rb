module Tkellem

class ListenAddress < ActiveRecord::Base
  validates_uniqueness_of :port, :scope => [:address]

  def to_s
    "#{address}:#{port} (ssl=#{!!ssl.inspect})"
  end
end

end
