class NetworkUser < Struct.new(:user, :network)
  def nick
    user.name
  end
end
