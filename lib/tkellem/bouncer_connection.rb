require 'eventmachine'
require 'tkellem/irc_line'
require 'tkellem/bouncer'

module BouncerConnection
  include EM::Protocols::LineText2

  @listeners = {}
  def self.listeners; @listeners; end

  def initialize(config)
    set_delimiter "\r\n"
    @config = config
    @backlog = []
    @listener = nil
    @bouncer = nil
    @nick = nil
    @conn_config = nil
  end
  attr_reader :config, :listener, :backlog, :bouncer, :nick, :conn_config

  def connected?
    !!listener
  end

  def name
    conn_config['name']
  end

  def post_init
    if config['ssl']
      debug "starting TLS"
      start_tls :verify_peer => false
    end
  end

  def ssl_handshake_completed
    debug "TLS complete"
  end

  def connect(conn_name, client_name, password)
    @listener = BouncerConnection.listeners[conn_name.downcase]
    unless listener
      send_msg(":tkellem!tkellem@tkellem PRIVMSG #{nick} :Unknown connection #{conn_name}")
      return
    end

    @conn_config = config['connections'][conn_name]['clients'].find { |c| c['name'] == client_name }
    unless conn_config
      send_msg(":tkellem!tkellem@tkellem PRIVMSG #{nick} :Unknown client #{client_name}, did you mean one of [#{config['connections'][conn_name]['clients'].map { |c| c['name'] }.join(", ")}]")
      return
    end

    # TODO: password auth

    @bouncer = listener.bouncer_connect(self)

    listener.send_welcome(self)
    bouncer.send_backlog(self)
    listener.rooms.each { |room| simulate_join(room) }
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
        listener.change_nick(msg.last)
      else
        @nick = msg.last
      end
    when /quit/i
      # DENIED
      close_connection
    else
      # pay it forward
      debug("got #{line.inspect}")
      listener.send_msg(msg)
    end
  end

  def simulate_join(room)
    send_msg(":#{listener.nick}!#{name}@tkellem JOIN #{room}")
    # TODO: intercept the NAMES response so that only this bouncer gets it
    # Otherwise other clients might show an "in this room" line.
    listener.send_msg("NAMES #{room}\r\n")
  end

  def transient_response(msg)
    send_msg(msg)
    if msg.command == "366"
      # finished joining this room, let's backlog it
      debug "got final NAMES for #{msg.args[1]}, sending backlog"
      bouncer.send_backlog(self, msg.args[1])
    end
  end

  def send_msg(msg)
    # debug("sending: #{msg}")
    send_data("#{msg}\r\n")
  end

  def debug(line)
    puts "#{config['name']}: #{line}"
  end

  def unbind
    listener.bouncer_disconnect(self) if connected?
  end

  def self.add_listener(listener)
    @listeners[listener.name.downcase] = listener
  end
end
