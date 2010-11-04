require 'eventmachine'
require 'tkellem/irc_line'
require 'tkellem/backlog'

module Tkellem

module BouncerConnection
  include EM::Protocols::LineText2

  def initialize(bouncer, do_ssl)
    set_delimiter "\r\n"

    @ssl = do_ssl
    @bouncer = bouncer

    @backlog = []
    @irc_server = nil
    @backlog = nil
    @nick = nil
    @conn_name = nil
    @name = nil
  end
  attr_reader :ssl, :irc_server, :backlog, :bouncer, :nick, :name

  def connected?
    !!irc_server
  end

  def name
    @name || "BouncerConnection.new"
  end

  def ssl?; ssl; end

  def post_init
    if ssl?
      debug "starting TLS"
      start_tls :verify_peer => false
    end
  end

  def ssl_handshake_completed
    debug "TLS complete"
  end

  def connect(conn_name, client_name, password)
    @irc_server = bouncer.get_irc_server(conn_name.downcase)
    unless irc_server
      send_msg(":tkellem!tkellem@tkellem PRIVMSG you :Unknown connection #{conn_name}")
      return
    end

    @conn_name = conn_name
    @name = client_name
    @backlog = irc_server.bouncer_connect(self)
    unless backlog
      send_msg(":tkellem!tkellem@tkellem PRIVMSG you :Unknown client #{client_name}")
      return
    end

    # TODO: password auth

    irc_server.send_welcome(self)
    backlog.send_backlog(self)
    irc_server.rooms.each { |room| simulate_join(room) }
  end

  def tkellem(msg)
    case msg.args.first
    when /nothing_yet/i
    else
      send_msg(":tkellem!tkellem@tkellem PRIVMSG #{nick} :Unknown tkellem command #{msg.args.first}")
    end
  end

  def receive_line(line)
    debug "client sez: #{line.inspect}"
    msg = IrcLine.parse(line)
    case msg.command
    when /tkellem/i
      tkellem(msg)
    when /pass/i
      @password = msg.args.first
    when /user/i
      conn_name, client_name = msg.args.last.strip.split(' ')
      connect(conn_name, client_name, @password)
    when /nick/i
      if connected?
        irc_server.change_nick(msg.last)
      else
        @nick = msg.last
      end
    when /quit/i
      # DENIED
      close_connection
    else
      if !connected?
        close_connection
      else
        # pay it forward
        debug("got #{line.inspect}")
        irc_server.send_msg(msg)
      end
    end
  end

  def simulate_join(room)
    send_msg(":#{irc_server.nick}!#{name}@tkellem JOIN #{room}")
    # TODO: intercept the NAMES response so that only this bouncer gets it
    # Otherwise other clients might show an "in this room" line.
    irc_server.send_msg("NAMES #{room}\r\n")
  end

  def transient_response(msg)
    send_msg(msg)
    if msg.command == "366"
      # finished joining this room, let's backlog it
      debug "got final NAMES for #{msg.args[1]}, sending backlog"
      backlog.send_backlog(self, msg.args[1])
    end
  end

  def send_msg(msg)
    # debug("sending: #{msg}")
    send_data("#{msg}\r\n")
  end

  def debug(line)
    puts "#{@conn_name}-#{name}: #{line}"
  end

  def unbind
    irc_server.bouncer_disconnect(self) if connected?
  end
end

end
