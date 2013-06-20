require 'openssl'
require 'celluloid/io'

module Tkellem
module CelluloidTools

# Generates a new SSL context with a new cert and key
# Great for easily getting up and running, but not necessarily a good idea for
# production use
def self.generate_ssl_ctx
  key = OpenSSL::PKey::RSA.new(2048)

  dn = OpenSSL::X509::Name.parse("/CN=tkellem-auto")
  cert = OpenSSL::X509::Certificate.new
  cert.version = 2
  cert.serial = 1
  cert.subject = dn
  cert.issuer = dn
  cert.public_key = key.public_key
  cert.not_before = Time.now
  cert.not_after = Time.now + 94670777 # 3 years
  cert.sign(key, OpenSSL::Digest::SHA1.new)

  ctx = OpenSSL::SSL::SSLContext.new
  ctx.key = key
  ctx.cert = cert

  ctx
end

class BackoffSupervisor < ::Celluloid::SupervisionGroup
  attr_reader :registry

  def restart_actor(actor, reason)
    member = @members.find do |member|
      member.actor == actor
    end
    raise "a group member went missing. This shouldn't be!" unless member

    if reason
    end

    member.restart(reason)
  end
end

class Listener < Struct.new(:server, :callback)
  include Celluloid::IO

  def self.start(*args, &callback)
    listener = self.new(*args)
    listener.callback = callback
    listener.async.run
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

class SSLListener < Listener
  def initialize(host, port)
    self.server = SSLServer.new(TCPServer.new(host, port), CelluloidTools.generate_ssl_ctx)
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
      line = readline.force_encoding(Encoding::UTF_8)
      receive_line(line)
    end
  rescue EOFError, IOError, OpenSSL::SSL::SSLError
    unbind
  end

  def receive_line(line)
  end

  def unbind
  end
end

end
end
