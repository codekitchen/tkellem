module Tkellem

class User < ActiveRecord::Base
  has_many :network_users, :dependent => :destroy
  has_many :networks, :dependent => :destroy

  validates_uniqueness_of :username
  validates_presence_of :role, :in => %w(user admin)

  # pluggable authentication -- add your own block, which takes |username, password|
  # parameters. Return a User object if authentication succeeded, or a
  # false/nil value if auth failed. You can create the user on-the-fly if
  # necessary.
  cattr_accessor :authentication_methods
  self.authentication_methods = []

  # default database-based authentication
  # TODO: proper password hashing
  self.authentication_methods << proc do |username, password|
    user = find_by_username(username)
    user && user.valid_password?(password) && user
  end

  def self.authenticate(username, password)
    authentication_methods.each do |m|
      result = m.call(username, password)
      return result if result.is_a?(self)
    end
    nil
  end

  def name
    username
  end

  def valid_password?(password)
    require 'openssl'
    self.password == OpenSSL::Digest::SHA1.hexdigest(password)
  end

  def admin?
    role == 'admin'
  end
end

end
