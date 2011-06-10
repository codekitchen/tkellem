class ListenAddress < Struct.new(:address, :port, :ssl)

  def self.all
    [self.new('0.0.0.0', 10001, true)]
  end

end
