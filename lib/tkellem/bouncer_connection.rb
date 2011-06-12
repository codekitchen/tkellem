require 'active_support/core_ext/object/blank'

require 'eventmachine'
require 'tkellem/irc_message'

module Tkellem

module BouncerConnection
  include EM::Protocols::LineText2
  include Tkellem::EasyLogger

  def initialize(tkellem_server, do_ssl)
    set_delimiter "\r\n"

    @ssl = do_ssl
    @tkellem = tkellem_server

    @state = :auth
    @name = 'new-conn'
    @data = {}
  end
  attr_reader :ssl, :bouncer, :name, :device_name
  alias_method :log_name, :name

  def nick
    @bouncer ? @bouncer.nick : @nick
  end

  def data(key)
    @data[key] ||= {}
  end

  def post_init
    if ssl
      start_tls :verify_peer => false
    else
      ssl_handshake_completed
    end
  end

  def ssl_handshake_completed
  end

  def error!(msg)
    info("ERROR :#{msg}")
    send_msg("ERROR :#{msg}")
    close_connection(true)
  end

  def connect_to_irc_server
    @bouncer = @tkellem.find_bouncer(@user, @conn_name)
    return error!("Unknown connection: #{@conn_name}") unless @bouncer
    @state = :connected
    info "connected"
    @bouncer.connect_client(self)
  end

  def msg_tkellem(msg)
    case msg.args.first
    when /nothing_yet/i
    else
      say_as_tkellem("Unknown tkellem command #{msg.args.first}")
    end
  end

  def say_as_tkellem(message)
    send_msg(":-tkellem!~tkellem@tkellem PRIVMSG #{nick} :#{message}")
  end

  def receive_line(line)
    trace "from client: #{line}"
    msg = IrcMessage.parse(line)

    command = msg.command
    if command == 'PRIVMSG' && msg.args.first == '-tkellem'
      msg_tkellem(IrcMessage.new(nil, 'TKELLEM', msg.args[1..-1]))
    elsif command == 'CAP'
      # TODO: full support for CAP -- this just gets mobile colloquy connecting
      if msg.args.first =~ /req/i
        send_msg("CAP NAK")
      end
    elsif command == 'PASS'
      unless @password
        @password = msg.args.first
      end
    elsif command == 'NICK' && @state == :auth
      @nick = msg.args.first
    elsif command == 'QUIT'
      close_connection
    elsif command == 'USER'
      msg_user(msg)
    elsif @state == :auth
      error!("Protocol error. You must authenticate first.")
    elsif @state == :connected
      @bouncer.client_msg(self, msg)
    else
      say_as_tkellem("You must connect to an irc network to do that.")
    end

  rescue => e
    error "Error handling message: {#{msg}} #{e}"
    e.backtrace.each { |l| error l }
    begin
      error! "Internal Tkellem error."
    rescue
    end
  end

  def msg_user(msg)
    unless @user
      @username, rest = msg.args.first.strip.split('@', 2).map { |a| a.downcase }
      @name = @username
      @user = User.authenticate(@username, @password)
      return error!("Unknown username: #{@username} or bad password.") unless @user

      if rest && !rest.empty?
        @conn_name, @device_name = rest.split(':', 2)
        # 'default' or missing device_name to use the default backlog
        # pass a device_name to have device-independent backlogs
        @device_name = @device_name.presence || 'default'
        @name = "#{@username}-#{@conn_name}"
        @name += "-#{@device_name}" if @device_name
        connect_to_irc_server
      else
        @name = "#{@username}-console"
        connect_to_tkellem_console
      end
    end
  end

  def connect_to_tkellem_console
    send_msg(":tkellem 001 #{nick} :Welcome to the Tkellem admin console")
    send_msg(":tkellem 376 #{nick} :End")
    @state = :console
  end

  def simulate_join(room)
    send_msg(":#{nick}!#{name}@tkellem JOIN #{room}")
    # TODO: intercept the NAMES response so that only this bouncer gets it
    # Otherwise other clients might show an "in this room" line.
    @bouncer.send_msg("NAMES #{room}\r\n")
  end

  def send_msg(msg)
    trace "to client: #{msg}"
    send_data("#{msg}\r\n")
  end

  def unbind
    @bouncer.disconnect_client(self) if @bouncer
  end
end

end
