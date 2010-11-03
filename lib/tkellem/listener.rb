require 'eventmachine'
require 'tkellem/irc_line'
require 'tkellem/bouncer_connection'
require 'tkellem/bouncer'

module Listener
  include EM::Protocols::LineText2

  def initialize(name, config)
    set_delimiter "\r\n"
    @name = name
    @config = config
    @welcomes = []
    @rooms = []
    @bouncers = {}
    @active_conns = []
    @nick = nil
    @joined_rooms = false
  end
  attr_reader :name, :config, :bouncers, :welcomes, :rooms, :nick, :active_conns

  def post_init
    if config['ssl']
      debug "starting TLS"
      start_tls :verify_peer => false
    else
      ssl_handshake_completed
    end
  end

  def ssl_handshake_completed
    debug "TLS complete"
    # send USER
    send_msg("USER tkellem localhost #{config['host']} :Testing")
    change_nick(config['nick'])
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
    else
      debug("got #{line.inspect}")
      bouncers.each { |name, bouncer| bouncer.handle_message(msg) }
    end
  end

  def got_welcome
    return if @joined_rooms
    @joined_rooms = true
    config['rooms'].each do |room_config|
      send_msg("JOIN #{room_config['name']}")
    end
  end

  def change_nick(new_nick)
    return if new_nick == @nick
    @nick = new_nick
    send_msg("NICK #{new_nick}")
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
    active_conns << bouncer_conn
    bouncers[bouncer_conn.name].add_conn(bouncer_conn)
    bouncers[bouncer_conn.name]
  end

  def bouncer_disconnect(bouncer_conn)
    bouncers[bouncer_conn.name].remove_conn(bouncer_conn)
    active_conns.delete(bouncer_conn)
  end
end
