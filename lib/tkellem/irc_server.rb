require 'set'
require 'eventmachine'
require 'tkellem/irc_line'
require 'tkellem/bouncer_connection'
require 'tkellem/backlog'

module Tkellem

module IrcServer
  include EM::Protocols::LineText2
  include Tkellem::EasyLogger

  def initialize(bouncer, name, do_ssl, nick)
    set_delimiter "\r\n"

    @bouncer = bouncer
    @name = name
    @ssl = do_ssl
    @nick = nick

    @max_backlog = nil
    @connected = false
    @welcomes = []
    @rooms = Set.new
    @backlogs = {}
    @active_conns = []
    @joined_rooms = false
    @pending_rooms = []
  end
  attr_reader :name, :backlogs, :welcomes, :rooms, :nick, :active_conns
  alias_method :log_name, :name

  def connected?
    @connected
  end

  def set_max_backlog(max_backlog)
    @max_backlog = max_backlog
    backlogs.each { |name, backlog| backlog.max_backlog = max_backlog }
  end

  def post_init
    if @ssl
      debug "starting TLS"
      # TODO: support strict cert checks
      start_tls :verify_peer => false
    else
      ssl_handshake_completed
    end
  end

  def ssl_handshake_completed
    # TODO: support sending a real username, realname, etc
    send_msg("USER #{nick} localhost blah :#{nick}")
    change_nick(nick, true)
  end

  def receive_line(line)
    trace "from server: #{line}"
    msg = IrcLine.parse(line)

    case msg.command
    when /0\d\d/, /2[56]\d/, /37[256]/
      welcomes << msg
      got_welcome if msg.command == "376" # end of MOTD
    when /join/i
      debug "joined #{msg.last}"
      rooms << msg.last
    when /ping/i
      send_msg("PONG #{nick}!tkellem #{msg.args.first}")
    when /pong/i
      # swallow it, we handle ping-pong from clients separately, in
      # BouncerConnection
    else
    end

    backlogs.each { |name, backlog| backlog.handle_message(msg) }
  end

  def got_welcome
    return if @joined_rooms
    @joined_rooms = true
    @pending_rooms.each do |room|
      join_room(room)
    end
    @pending_rooms.clear

    # We're all initialized, allow connections
    @connected = true
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
    return if backlogs[name]
    backlog = Backlog.new(name, @max_backlog)
    backlogs[name] = backlog
  end

  def remove_client(name)
    backlog = backlogs.delete(name)
    if backlog
      backlog.active_conns.each do |conn|
        conn.error!("client removed")
      end
    end
  end

  def send_msg(msg)
    trace "to server: #{msg}"
    send_data("#{msg}\r\n")
  end

  def send_welcome(bouncer_conn)
    welcomes.each { |msg| bouncer_conn.send_msg(msg) }
  end

  def unbind
    debug "OMG we got disconnected."
    # TODO: reconnect if desired. but not if this server was explicitly shut
    # down or removed.
    backlogs.keys.each { |name| remove_client(name) }
  end

  def bouncer_connect(bouncer_conn)
    return nil unless backlogs[bouncer_conn.name]

    active_conns << bouncer_conn
    backlogs[bouncer_conn.name].add_conn(bouncer_conn)
    backlogs[bouncer_conn.name]
  end

  def bouncer_disconnect(bouncer_conn)
    return nil unless backlogs[bouncer_conn.name]

    backlogs[bouncer_conn.name].remove_conn(bouncer_conn)
    active_conns.delete(bouncer_conn)
  end
end

end
