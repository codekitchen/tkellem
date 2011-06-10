class Network < Struct.new(:a)
  def name
    "localhost"
  end

  class Host < Struct.new(:address, :port, :ssl)
  end

  def hosts
    [Host.new('localhost', 8765, false)]
  end
end
