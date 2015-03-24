require 'tkellem/bouncer_connection'
require 'tkellem/sasl/base'

module Tkellem
module SASL

# Should inherit and implement authorize
class Plain < Base
  attr_reader :passwd

  def response(response)
    return '' unless response
    @authzid, @authcid, @passwd = response.split("\0", 3)
    unless authenticate
      @authzid, @authcid, @passwd = nil
    end
    nil
  end
end

end
end