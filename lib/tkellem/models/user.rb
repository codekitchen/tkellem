module Tkellem

class User < ActiveRecord::Base
  def self.authenticate(username, password)
    user = find_by_username(username)
    user && user.valid_password?(password) && user
  end

  def name
    username
  end

  def valid_password?(password)
    require 'openssl'
    self.password == OpenSSL::Digest::SHA1.hexdigest(password)
  end
end

end
