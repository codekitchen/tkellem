require 'set'
require 'eventmachine'
require 'tkellem/irc_message'
require 'tkellem/bouncer_connection'
require 'tkellem/backlog'

module Tkellem

class IrcServer
  attr_reader :rooms, :backlogs, :conn

  def initialize(bouncer, name, nick)
    @bouncer = bouncer
    @name = name
    @nick = nick
    @cur_host = -1
    @hosts = []

    @max_backlog = nil
    @backlogs = {}
    @rooms = []
  end

  def connected?
    @conn && @conn.connected?
  end

  def add_host(host, port, do_ssl)
    @hosts << [host, port, do_ssl]
    connect! if @hosts.length == 1
  end

  def set_max_backlog(max_backlog)
    @max_backlog = max_backlog
    backlogs.each { |name, backlog| backlog.max_backlog = max_backlog }
  end

  def join_room(room)
    @rooms << room
    @conn.join_room(room) if connected?
  end

  def add_client(name)
    return if backlogs[name]
    backlog = Backlog.new(name, @max_backlog)
    backlogs[name] = backlog
  end

  def disconnected!
    @conn = nil
    connect!
  end

  protected

  def connect!
    span = @last_connect ? Time.now - @last_connect : 1000
    if span < 5
      EM.add_timer(5) { connect! }
      return
    end
    @last_connect = Time.now
    @cur_host += 1
    @cur_host = @cur_host % @hosts.length
    host = @hosts[@cur_host]
    @conn = EM.connect(host[0], host[1], IrcServerConnection, self, @name, host[2], @nick)
  end
end

module IrcServerConnection
  include EM::Protocols::LineText2
  include Tkellem::EasyLogger

  def initialize(irc_server, name, do_ssl, nick)
    set_delimiter "\r\n"

    @irc_server = irc_server
    @name = name
    @ssl = do_ssl
    @nick = nick

    @connected = false
    @welcomes = []
    @rooms = Set.new
    @active_conns = []
    @joined_rooms = false
  end
  attr_reader :name, :welcomes, :rooms, :nick, :active_conns
  alias_method :log_name, :name

  def connected?
    @connected
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
    msg = IrcMessage.parse(line)

    case msg.command
    when /0\d\d/, /2[56]\d/, /37[256]/
      welcomes << msg
      got_welcome if msg.command == "376" # end of MOTD
    when /join/i
      debug "#{msg.target_user} joined #{msg.args.last}"
      rooms << msg.args.last if msg.target_user == nick
    when /part/i
      debug "#{msg.target_user} left #{msg.args.last}"
      rooms.delete(msg.args.last) if msg.target_user == nick
    when /ping/i
      send_msg("PONG #{nick}!tkellem :#{msg.args.last}")
    when /pong/i
      # swallow it, we handle ping-pong from clients separately, in
      # BouncerConnection
    else
    end

    @irc_server.backlogs.each { |name, backlog| backlog.handle_message(msg) }
  end

  def got_welcome
    return if @joined_rooms
    @joined_rooms = true
    @irc_server.rooms.each do |room|
      join_room(room)
    end

    # We're all initialized, allow connections
    @connected = true
  end

  def change_nick(new_nick, force = false)
    return if !force && new_nick == @nick
    @nick = new_nick
    send_msg("NICK #{new_nick}")
  end

  def join_room(room_name)
    send_msg("JOIN #{room_name}")
  end

  def remove_client(name)
    backlog = @irc_server.backlogs[name]
    if backlog
      backlog.active_conns.each do |conn|
        conn.error!("client disconnected")
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
    @irc_server.backlogs.keys.each { |name| remove_client(name) }
    @irc_server.disconnected!
  end

  def bouncer_connect(bouncer_conn)
    return nil unless @irc_server.backlogs[bouncer_conn.name]

    active_conns << bouncer_conn
    @irc_server.backlogs[bouncer_conn.name].add_conn(bouncer_conn)
    @irc_server.backlogs[bouncer_conn.name]
  end

  def bouncer_disconnect(bouncer_conn)
    return nil unless @irc_server.backlogs[bouncer_conn.name]

    @irc_server.backlogs[bouncer_conn.name].remove_conn(bouncer_conn)
    active_conns.delete(bouncer_conn)
  end
end

end
