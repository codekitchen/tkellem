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
    failsafe(:post_init) do
      if @ssl
        @bouncer.debug "starting TLS"
        # TODO: support strict cert checks
        start_tls :verify_peer => false
      else
        ssl_handshake_completed
      end
    end
  end

  def ssl_handshake_completed
    failsafe(:ssl_handshake_completed) do
      EM.next_tick { @bouncer.connection_established(self) }
    end
  end

  def receive_line(line)
    failsafe(:receive_line) do
      trace "from server: #{line}"
      msg = IrcMessage.parse(line)
      @bouncer.server_msg(msg)
    end
  end

  def unbind
    failsafe(:unbind) do
      @bouncer.disconnected!
    end
  end
end

end
