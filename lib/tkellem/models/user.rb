module Tkellem

class User < Sequel::Model
  plugin :validation_class_methods

  one_to_many :network_users, :dependent => :destroy
  one_to_many :networks, :dependent => :destroy

  validates_presence_of :username
  validates_uniqueness_of :username
  validates_presence_of :role, :in => %w(user admin)

  def before_validation
    self.role ||= 'user'
    super
  end

  # pluggable authentication -- add your own block, which takes |username, password|
  # parameters. Return a User object if authentication succeeded, or a
  # false/nil value if auth failed. You can create the user on-the-fly if
  # necessary.
  cattr_accessor :authentication_methods
  self.authentication_methods = []

  # default database-based authentication
  # TODO: proper password hashing
  self.authentication_methods << proc do |username, password|
    user = first(:username => username)
    user && user.valid_password?(password) && user
  end

  def self.authenticate(username, password)
    authentication_methods.each do |m|
      result = m.call(username, password)
      return result if result.is_a?(self)
    end
    nil
  end

  def username=(val)
    super(val.try(:downcase))
  end

  def name
    username
  end

  def valid_password?(password)
    require 'openssl'
    self.password == OpenSSL::Digest::SHA1.hexdigest(password)
  end

  def password=(password)
    super(password ? OpenSSL::Digest::SHA1.hexdigest(password) : nil)
  end

  def admin?
    role == 'admin'
  end
end

end
