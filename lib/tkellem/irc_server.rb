require 'eventmachine'
require 'set'
require 'socket'

require 'tkellem/irc_message'
require 'tkellem/bouncer_connection'

module Tkellem

module IrcServerConnection
  include EM::Protocols::LineText2

  def initialize(connection_state, bouncer, do_ssl)
    set_delimiter "\r\n"
    @bouncer = bouncer
    @ssl = do_ssl
    @connection_state = connection_state
    @connected = false
  end

  def connection_completed
    if @ssl
      @bouncer.failsafe(:connection_completed) do
        @bouncer.debug "starting TLS"
        # TODO: support strict cert checks
        start_tls :verify_peer => false
      end
    else
      ssl_handshake_completed
    end
  end

  def ssl_handshake_completed
    @bouncer.failsafe(:ssl_handshake_completed) do
      @connected = true
      @bouncer.connection_established(self)
    end
  end

  def receive_line(line)
    @bouncer.failsafe(:receive_line) do
      @bouncer.trace "from server: #{line}"
      msg = IrcMessage.parse(line)
      @bouncer.server_msg(msg)
    end
  end

  def unbind
    @bouncer.failsafe(:unbind) do
      if @connected
        @bouncer.disconnected!
      else
        @bouncer.debug "Connection failed, trying next"
        @connection_state.connect!
      end
    end
  end

  class ConnectionState < Struct.new(:bouncer, :network, :attempted, :getting)
    def initialize(bouncer, network)
      super(bouncer, network, Set.new, false)
      reset
    end

    def connect!
      raise("already in the process of getting an address") if getting
      self.getting = true
      network.reload
      host_infos = network.hosts.map { |h| h.attributes }
      EM.defer(proc { find_address(host_infos) }, method(:got_address))
    end

    def reset
      self.attempted.clear
    end

    # runs in threadpool
    def find_address(hosts)
      candidates = Set.new
      hosts.each do |host|
        Socket.getaddrinfo(host['address'], host['port'], Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP).each do |found|
          candidates << [found[3], host['port'], host['ssl']]
        end
      end

      to_try = candidates.to_a.sort_by { rand }.find { |c| !attempted.include?(c) }
      if to_try.nil?
        # we've tried all possible hosts, start over
        return nil
      end

      return to_try
    end

    # back on event thread
    def got_address(to_try)
      self.getting = false

      if !to_try
        # sleep for a bit and try again
        bouncer.debug "All available addresses failed, sleeping 5s and then trying over"
        reset
        EM.add_timer(5) { connect! }
        return
      end

      attempted << to_try
      address, port, ssl = to_try

      bouncer.debug "Connecting to: #{Host.address_string(address, port, ssl)}"
      bouncer.failsafe("connect: #{Host.address_string(address, port, ssl)}") do
        EM.connect(address, port, IrcServerConnection, self, bouncer, ssl)
      end
    end
  end

  def self.connector(bouncer, network)
    ConnectionState.new(bouncer, network)
  end

end

end
