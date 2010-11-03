require 'eventmachine'
require 'tkellem/irc_line'
require 'tkellem/bouncer'

module BouncerConnection
  include EM::Protocols::LineText2

  def initialize(listener, server_config, config)
    set_delimiter "\r\n"
    @listener = listener
    @server_config = server_config
    @config = config
    @backlog = []
  end
  attr_reader :server_config, :config, :listener, :backlog, :bouncer

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
    # TODO: Auth
    @bouncer = listener.bouncer_connect(self)
  end

  def receive_line(line)
    msg = IrcLine.parse(line)
    case msg.command
    when /user/i
      listener.send_welcome(self)
      listener.rooms.each { |room| simulate_join(room) }
    when /nick/i
      listener.change_nick(msg.last)
    when /quit/i
      # DENIED
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

  def name_response(msg)
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

  def name
    config['name']
  end

  def unbind
    listener.bouncer_disconnect(self)
  end
end
