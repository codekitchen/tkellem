class User < Struct.new(:name)
  def initialize(*a)
    super
    @@users ||= []
    @@users << self
  end

  def self.authenticate(username, password)
    if password == 'asdf'
      @@users.find { |u| u.name == username }
    else
      nil
    end
  end

  def id
    name
  end
end
