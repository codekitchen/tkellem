module Tkellem
module CelluloidTools

class Listener < Struct.new(:server, :callback)
  include Celluloid::IO

  def self.start(*args, &callback)
    listener = self.new(*args)
    listener.callback = callback
    listener.run!
    listener
  end

  def run
    loop { handle_connection(server.accept) }
  end

  def handle_connection(socket)
    callback.(socket)
  end

  finalizer :close

  def close
    server.try(:close) unless server.try(:closed?)
  end
end

class TCPListener < Listener
  def initialize(host, port)
    self.server = TCPServer.new(host, port)
  end
end

class UnixListener < Listener
  def initialize(socket_path)
    self.server = UNIXServer.new(socket_path)
  end
end

module LineReader
  def self.included(k)
    k.send :finalizer, :close_connection
  end

  def readline
    @delimiter ||= "\r\n"
    @readline_buffer ||= ''
    loop do
      if idx = @readline_buffer.index(@delimiter)
        postidx = idx + @delimiter.size
        line = @readline_buffer[0, postidx]
        @readline_buffer = @readline_buffer[postidx..-1]
        return line
      else
        @socket.readpartial(4096, @readline_buffer)
      end
    end
  end

  def close_connection
    @socket.close if @socket && !@socket.closed?
  end

  def run
    loop do
      line = readline
      receive_line(line)
    end
  rescue EOFError, IOError
    unbind
  end

  def receive_line(line)
  end

  def unbind
  end
end

end
end
