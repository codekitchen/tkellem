require 'set'
require 'eventmachine'
require 'tkellem/irc_message'
require 'tkellem/bouncer_connection'

module Tkellem

module IrcServerConnection
  include EM::Protocols::LineText2
  include Tkellem::EasyLogger

  def initialize(bouncer, do_ssl)
    set_delimiter "\r\n"
    @bouncer = bouncer
    @ssl = do_ssl
  end

  def post_init
    if @ssl
      @bouncer.debug "starting TLS"
      # TODO: support strict cert checks
      start_tls :verify_peer => false
    else
      ssl_handshake_completed
    end
  end

  def ssl_handshake_completed
    EM.next_tick { @bouncer.connection_established }
  end

  def receive_line(line)
    trace "from server: #{line}"
    msg = IrcMessage.parse(line)
    @bouncer.server_msg(msg)
  end

  def unbind
    @bouncer.disconnected!
  end
end

end
