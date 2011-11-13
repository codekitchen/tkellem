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
  attr_reader :ssl, :bouncer, :name, :device_name, :connecting_nick
  alias_method :log_name, :name

  def nick
    @bouncer ? @bouncer.nick : @connecting_nick
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
    TkellemBot.run_command(msg.args.join(' '), @bouncer) do |response|
      say_as_tkellem(response)
    end
  end

  def say_as_tkellem(message)
    send_msg(":-tkellem!~tkellem@tkellem PRIVMSG #{nick} :#{message}")
  end

  def receive_line(line)
    trace "from client: #{line}"
    msg = IrcMessage.parse(line)

    command = msg.command
    if @user && command == 'PRIVMSG' && msg.args.first == '-tkellem'
      msg_tkellem(IrcMessage.new(nil, 'TKELLEM', [msg.args.last]))
    elsif command == 'TKELLEM'
      msg_tkellem(msg)
    elsif command == 'CAP'
      # TODO: full support for CAP -- this just gets mobile colloquy connecting
      if msg.args.first =~ /req/i
        send_msg("CAP NAK")
      end
    elsif command == 'PASS' && @state == :auth
      @password = msg.args.first
    elsif command == 'NICK' && @state == :auth
      @connecting_nick = msg.args.first
      maybe_connect
    elsif command == 'QUIT'
      close_connection
    elsif command == 'USER' && @state == :auth
      unless @username
        @username, @conn_info = msg.args.first.strip.split('@', 2).map { |a| a.downcase }
      end
      maybe_connect
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

  def maybe_connect
    if @connecting_nick && @username && @password && !@user
      @name = @username
      @user = User.authenticate(@username, @password)
      return error!("Unknown username: #{@username} or bad password.") unless @user

      if @conn_info && !@conn_info.empty?
        @conn_name, @device_name = @conn_info.split(':', 2)
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
    send_msg(":#{nick} JOIN #{room}")
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
