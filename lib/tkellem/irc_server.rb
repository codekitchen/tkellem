# encoding: utf-8
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
      line.force_encoding Encoding::UTF_8
      @bouncer.trace "from server: #{line}"
      return if line.blank?
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

  class ConnectionState < Struct.new(:bouncer, :network, :to_try, :getting)
    def initialize(bouncer, network)
      super(bouncer, network, nil, false)
    end

    def connect!
      if !to_try.nil? && !to_try.empty?
        address, port, ssl, af = to_try.shift
        friendly_address = af == 'AF_INET6' ? "[#{address}]" : address

        bouncer.debug "Connecting to: #{Host.address_string(friendly_address, port, ssl)}"
        bouncer.failsafe("connect: #{Host.address_string(friendly_address, port, ssl)}") do
          EM.connect(address, port, IrcServerConnection, self, bouncer, ssl)
        end
      elsif !to_try.nil?
        # sleep for a bit and try again
        bouncer.debug "All available addresses failed, sleeping 5s and then trying over"
        self.to_try = nil
        EM.add_timer(5) { connect! }
      else
        raise("already in the process of getting an address") if getting
        self.getting = true
        network.reload
        host_infos = network.hosts.map(&:attributes)
        EM.defer(proc { find_address(host_infos) }, method(:got_address))
      end
    end

    # runs in threadpool
    def find_address(hosts)
      candidates = Set.new
      hosts.each do |host|
        Socket.getaddrinfo(host['address'], host['port'], Socket::AF_UNSPEC, Socket::SOCK_STREAM, Socket::IPPROTO_TCP).each do |found|
          candidates << [found[3], host['port'], host['ssl'], found[0]]
        end
      end

      # prefer IPv6; if no IPv6 connectivity, they'll fail fast
      self.to_try = candidates.to_a.sort_by { |c| [c.last == 'AF_INET6' ? 0 : 1, rand] }
    end

    # back on event thread
    def got_address(_)
      self.getting = false
      connect!
    end
  end

  def self.connector(bouncer, network)
    ConnectionState.new(bouncer, network)
  end

end

end
