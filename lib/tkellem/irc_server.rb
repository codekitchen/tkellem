require 'set'
require 'eventmachine'
require 'tkellem/irc_line'
require 'tkellem/bouncer_connection'
require 'tkellem/backlog'

module Tkellem

module IrcServer
  include EM::Protocols::LineText2

  def initialize(bouncer, name, do_ssl, nick)
    set_delimiter "\r\n"

    @bouncer = bouncer
    @name = name
    @ssl = do_ssl
    @nick = nick

    @welcomes = []
    @rooms = Set.new
    @backlogs = {}
    @active_conns = []
    @joined_rooms = false
    @pending_rooms = []
  end
  attr_reader :name, :backlogs, :welcomes, :rooms, :nick, :active_conns

  def post_init
    if @ssl
      debug "starting TLS"
      start_tls :verify_peer => false
    else
      ssl_handshake_completed
    end
  end

  def ssl_handshake_completed
    debug "TLS complete"
    # TODO: support sending a real username, realname, etc
    send_msg("USER #{@nick} localhost blah :Testing")
    change_nick(@nick, true)
  end

  def receive_line(line)
    msg = IrcLine.parse(line)

    if msg.command.match(/join/i)
      debug("joined #{msg.last}")
      rooms << msg.last
    end

    case msg.command
    when /0\d\d/, /2[56]\d/, /37[256]/
      welcomes << msg
      got_welcome
    when /3\d\d/, /join/i
      # transient response -- we want to forward these, but not backlog
      active_conns.each { |conn| conn.transient_response(msg) }
    when /ping/i
      send_msg("PONG #{nick}!tkellem #{msg.args.first}")
    when /pong/i
      # swallow it, we handle ping-pong from clients separately, in
      # BouncerConnection
    else
      debug("got #{line.inspect}")
      backlogs.each { |name, backlog| backlog.handle_message(msg) }
    end
  end

  def got_welcome
    return if @joined_rooms
    @joined_rooms = true
    @pending_rooms.each do |room|
      join_room(room)
    end
    @pending_rooms.clear

    # We're all initialized, allow connections
    @bouncer.irc_server_ready(self)
  end

  def change_nick(new_nick, force = false)
    return if !force && new_nick == @nick
    @nick = new_nick
    send_msg("NICK #{new_nick}")
  end

  def join_room(room_name)
    if @joined_rooms
      send_msg("JOIN #{room_name}")
    else
      @pending_rooms << room_name
    end
  end

  def add_client(name)
      backlogs[name] = Backlog.new(name)
  end

  def send_msg(msg)
    send_data("#{msg}\r\n")
  end

  def send_welcome(bouncer_conn)
    welcomes.each { |msg| bouncer_conn.send_msg(msg) }
  end

  def debug(line)
    puts "#{name}: #{line}"
  end

  def unbind
    debug "OMG we got disconnected. everybody dies."
    # TODO: don't die
    EM.stop
  end

  def bouncer_connect(bouncer_conn)
    return nil unless backlogs[bouncer_conn.name]

    active_conns << bouncer_conn
    backlogs[bouncer_conn.name].add_conn(bouncer_conn)
    backlogs[bouncer_conn.name]
  end

  def bouncer_disconnect(bouncer_conn)
    backlogs[bouncer_conn.name].remove_conn(bouncer_conn)
    active_conns.delete(bouncer_conn)
  end
end

end
