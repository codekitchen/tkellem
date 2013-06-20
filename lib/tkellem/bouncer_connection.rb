require 'active_support/core_ext/object/blank'
require 'celluloid/io'

require 'tkellem/irc_message'
require 'tkellem/celluloid_tools'

module Tkellem

class BouncerConnection
  include Celluloid::IO
  include Tkellem::EasyLogger
  include Tkellem::CelluloidTools::LineReader

  def initialize(tkellem_server, socket)
    @tkellem = tkellem_server
    @socket = socket

    @state = :auth
    @name = 'new-conn'
    @data = {}
    @connected_at = Time.now
  end
  attr_reader :ssl, :bouncer, :name, :device_name, :connecting_nick, :connected_at
  alias_method :log_name, :name

  def nick
    @bouncer ? @bouncer.nick : @connecting_nick
  end

  def data(key)
    @data[key] ||= {}
  end

  def error!(msg)
    info("ERROR :#{msg}")
    say_as_tkellem(msg)
    send_msg("ERROR :#{msg}")
    close_connection
  end

  def connect_to_irc_server
    @bouncer = @tkellem.find_bouncer(@user, @conn_name)
    return error!("Unknown connection: #{@conn_name}") unless @bouncer
    @state = :connected
    info "connected"
    @bouncer.connect_client(self)
  end

  def msg_tkellem(msg)
    case @state
    when :password
      user = User.create(:username => @username, :password => msg.args.last, :role => 'user')
      if user.errors.any?
        error!("There was an error creating your user account. Please try again, or contact the tkellem admin.")
      else
        @user = user
        say_as_tkellem("Your account has been created. Set your password in your IRC client and re-connect to start using tkellem.")
      end
    else
      if @user
        TkellemBot.run_command(msg.args.join(' '), @user, @bouncer.try(:network_user)) do |response|
          say_as_tkellem(response)
        end
      end
    end
  end

  def say_as_tkellem(message)
    send_msg(":-tkellem!~tkellem@tkellem PRIVMSG #{nick} :#{message}")
  end

  def receive_line(line)
    trace "from client: #{line}"
    return if line.blank?
    msg = IrcMessage.parse(line)

    command = msg.command
    if @state != :auth && command == 'PRIVMSG' && msg.args.first == '-tkellem'
      msg_tkellem(IrcMessage.new(nil, 'TKELLEM', [msg.args.last]))
    elsif command == 'TKELLEM' || command == 'TK'
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
  end

  def maybe_connect
    return unless @connecting_nick && @username && !@user
    if @password
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
    else
      user = User.find_by_username(@username)
      if user || user_registration == 'closed'
        error!("No password given. Make sure to set your password in your IRC client config, and connect again.")
        if user_registration != 'closed'
          error!("If you are trying to register for a new account, this username is already taken. Please select another.")
        end
      else
        @state = :registration
        say_as_tkellem "Welcome to tkellem, #{@username}. If you already have an account and were trying to connect, please check your username, as it wasn't recognized."
        say_as_tkellem "Otherwise, follow these instructions to create an account."
        say_as_tkellem ' '
        user_registration_get_password
      end
    end
  end

  def user_registration
    val = Setting.get('user_registration')
    %(open verified).include?(val) ? val : 'closed'
  end

  def user_registration_get_password
    @state = :password
    say_as_tkellem "You need to set an initial password for your account. Enter your password now:"
  end

  def connect_to_tkellem_console
    send_msg(":tkellem 001 #{nick} :Welcome to the Tkellem admin console")
    send_msg(":tkellem 376 #{nick} :End")
    @state = :console
  end

  def simulate_join(room)
    send_msg(":#{nick} JOIN #{room.name}")
    # TODO: intercept the NAMES response so that only this bouncer gets it
    # Otherwise other clients might show an "in this room" line.
    @bouncer.send_msg("NAMES #{room.name}\r\n")
    send_msg(IrcMessage.new(":tkellem", "332",  [nick, room.name, room.topic])) if room.topic
    send_msg(IrcMessage.new(":tkellem", "333",  [nick, room.name, room.topic_setter, room.topic_time])) if room.topic_setter && room.topic_time
  end

  def send_msg(msg)
    return if @socket.closed?
    trace "to client: #{msg}"
    @socket.write("#{msg}\r\n")
  end

  def unbind
    @bouncer.try(:disconnect_client, self)
  end
end

end
