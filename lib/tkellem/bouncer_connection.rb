# encoding: utf-8
require 'active_support/core_ext/object/blank'

require 'base64'
require 'eventmachine'
require 'tkellem/irc_message'
require 'tkellem/sasl/plain'
require 'tkellem/sasl/dh_aes'
require 'tkellem/sasl/dh_blowfish'

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
    @connected_at = Time.now
    @caps = Set.new
    @tags = false
  end
  attr_reader :ssl, :bouncer, :name, :device_name, :connecting_nick, :connected_at, :caps, :tags
  alias_method :log_name, :name

  def nick
    @bouncer ? @bouncer.nick : @connecting_nick || '*'
  end

  def data(key)
    @data[key] ||= {}
  end

  def start_tls
    @ssl = true
    options = { verify_peer: false }
    options[:private_key_file] = Setting.get('private_key_file').presence
    options[:cert_chain_file] = Setting.get('cert_chain_file').presence
    super options
  end

  def post_init
    failsafe(:post_init) do
      if ssl
        start_tls
      else
        ssl_handshake_completed
      end
    end
  end

  def ssl_handshake_completed
  end

  def schedule_ping_client
    EM::Timer.new(60) { ping_client }
  end

  def ping_client
    failsafe("ping_client") do
      send_msg("PING tkellem")
      @ping_timer = EM::Timer.new(10) do
        # ping timeout
        info("PING timeout, closing connection")
        close_connection
      end
    end
  end

  def error!(msg)
    info("ERROR :#{msg}")
    say_as_tkellem(msg)
    send_msg("ERROR :#{msg}")
    close_connection(true)
  end

  def connect_to_irc_server
    @bouncer = @tkellem.find_bouncer(@user, @conn_name)
    return error!("Unknown connection: #{@conn_name}") unless @bouncer
    @state = :connected
    info "connected"
    schedule_ping_client
    @bouncer.connect_client(self)
  end

  def msg_tkellem(msg)
    case @state
    when :recaptcha
      if @recaptcha.valid_response?(msg.args.last)
        say_as_tkellem "Looks like you're human. Whew, I hate robots."
        user_registration_get_password
      else
        say_as_tkellem "Nope, that's not right. Please try again."
      end
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
        TkellemBot.run_command(msg.args.join(' '), @bouncer, self) do |response|
          say_as_tkellem(response)
        end
      end
    end
  end

  def say_as_tkellem(message)
    send_msg(":-tkellem!~tkellem@tkellem PRIVMSG #{nick} :#{message}")
  end

  def self.caps
    @caps ||= Set.new
  end
  def self.tag_caps
    @tag_caps ||= Set.new
  end

  def self.register_cap(*caps)
    self.caps.merge(caps)
  end

  def self.register_tag_cap(*caps)
    self.tag_caps.merge(caps)
    self.caps.merge(caps)
  end

  register_cap 'tls'
  register_cap 'sasl'

  def self.sasl_mechanisms
    @sasl_mechanisms ||= {}
  end
  def self.register_sasl(mechanism, klass)
    sasl_mechanisms[mechanism] = klass
  end

  module TkellemSaslAuthenticate
    def authenticate
      return false unless authcid
      username, _, _ = BouncerConnection.parse_username(authcid)

      !!User.authenticate(username, passwd)
    end
  end

  class TkellemPlainSasl < SASL::Plain
    include TkellemSaslAuthenticate
  end
  register_sasl('PLAIN', TkellemPlainSasl)

  class TkellemDhBlowfishSasl < SASL::DhBlowfish
    include TkellemSaslAuthenticate
  end
  register_sasl('DH-BLOWFISH', TkellemDhBlowfishSasl)

  class TkellemDhAesSasl < SASL::DhAes
    include TkellemSaslAuthenticate
  end
  register_sasl('DH-AES', TkellemDhAesSasl)

  def receive_line(line)
    failsafe("message: {#{line}}") do
      line.force_encoding Encoding::UTF_8
      trace "from client: #{line}"
      return if line.blank?
      msg = IrcMessage.parse(line)

      command = msg.command
      if @state != :auth && command == 'PRIVMSG' && msg.args.first == '-tkellem'
        msg_tkellem(IrcMessage.new(nil, 'TKELLEM', [msg.args.last]))
      elsif command == 'TKELLEM' || command == 'TK'
        msg_tkellem(msg)
      elsif command == 'PONG'
        if @ping_timer
          @ping_timer.cancel
          @ping_timer = nil
          # only schedule again if @ping_timer existed, so we don't schedule
          # multiple if the client just randomly sends PONGs
          schedule_ping_client
        end
      elsif command == 'CAP'
        case msg.args.first
        when 'LS'
          send_msg(":tkellem CAP #{nick} LS :#{BouncerConnection.caps.to_a.join(' ')}")
        when 'REQ'
          reqs = msg.args.last.split(' ')
          adds = []; removes = []
          reqs.each do |req|
            if req[0] == '-'
              removes << req[1..-1]
            else
              adds << req
            end
          end
          if !(adds - BouncerConnection.caps.to_a).empty? || !(removes - BouncerConnection.caps.to_a).empty?
            send_msg(":tkellem CAP #{nick} NAK :#{msg.args.last}")
          else
            @caps += adds
            @caps -= removes
            @tags = !(@caps & BouncerConnection.tag_caps).empty?
            send_msg(":tkellem CAP #{nick} ACK :#{msg.args.last}")
          end
        when 'LIST'
          send_msg(":tkellem CAP #{nick} LIST :#{caps.to_a.join(' ')}")
        when 'CLEAR'
          @tags = false
          send_msg(":tkellem CAP #{nick} ACK :#{caps.map { |cap| "-#{cap}" }.join(' ') }")
        when 'END'
          # do nothing
        else
          error!("Unrecognized CAP subcommand")
        end
      elsif command == 'PASS' && @state == :auth
        @password = msg.args.first
      elsif command == 'AUTHENTICATE' && @state == :auth && caps.include?('sasl')
        if msg.args.first == '*'
          @sasl = nil
          return send_msg(":tkellem 906 :SASL authentication aborted")
        end
        if !@sasl
          mechanism = msg.args.first
          if !BouncerConnection.sasl_mechanisms[mechanism]
            return send_msg(":tkellem 904 #{nick} :SASL mechanism not supported")
          end
          @sasl = BouncerConnection.sasl_mechanisms[mechanism].new
          response = nil
        else
          @sasl_response += msg.args.last
          return if msg.args.last.length == 400
          response = Base64.decode64(@sasl_response)
        end
        challenge = @sasl.response(response)
        if challenge
          @sasl_response = ''
          challenge = Base64.strict_encode64(challenge)
          while challenge.length >= 400
            send_msg("AUTHENTICATE #{challenge[0..400]}")
            challenge.slice!(0...400)
          end
          challenge = '+' if challenge.empty?
          send_msg("AUTHENTICATE #{challenge}")
        else
          @username, @conn_name, @device_name = BouncerConnection.parse_username(@sasl.authcid) if @sasl.authcid
          if @sasl.authcid && @user = User.where(username: @username).first
            send_msg(":tkellem 900 #{nick} :You are now logged in")
            send_msg(":tkellem 903 #{nick} :SASL authentication successful")
            maybe_connect
          else
            send_msg(":tkellem 904 #{nick} :SASL authentication failed")
          end
          @sasl = nil
        end
      elsif command == 'AUTHENTICATE' && @state != :auth && caps.include?('sasl')
        send_msg(":tkellem 907 :Already authenticated")
      elsif command == 'NICK' && @state == :auth
        @connecting_nick = msg.args.first
        maybe_connect
      elsif command == 'QUIT'
        close_connection
      elsif command == 'USER' && @state == :auth
        unless @username
          @username, @conn_name, @device_name = BouncerConnection.parse_username(msg.args.first)
        end
        maybe_connect
      elsif command == 'STARTTLS' && !@ssl
        send_msg("670 :STARTTLS successful, go ahead with TLS handshake")
        start_tls
      elsif command == 'PING' && @state == :auth
        send_msg("PONG #{msg.args.first}")
      elsif @state == :auth
        error!("Protocol error. You must authenticate first.")
      elsif @state == :connected
        @bouncer.client_msg(self, msg)
      else
        say_as_tkellem("You must connect to an irc network to do that.")
      end
    end
  end

  def self.parse_username(username)
    username, conn_info = username.downcase.split('@', 2)
    conn_name, device_name = conn_info.split(':', 2) if conn_info
    device_name ||= 'default'
    [username, conn_name, device_name]
  end

  def maybe_connect
    return unless @connecting_nick && @username
    if @password || @user
      @user ||= User.authenticate(@username, @password)
      return error!("Unknown username: #{@username} or bad password.") unless @user

      if @conn_name
        @name = "#{@username}-#{@conn_name}-#{device_name}"
        connect_to_irc_server
      else
        @name = "#{@username}-console"
        connect_to_tkellem_console
      end
    else
      user = User.where(username: @username).first
      if user || user_registration == 'closed'
        # wait longer for a SASL password
        return if caps.include?('sasl')
        #error!("No password given. Make sure to set your password in your IRC client config, and connect again.")
        if user_registration != 'closed'
          error!("If you are trying to register for a new account, this username is already taken. Please select another.")
        end
      else
        @state = :registration
        say_as_tkellem "Welcome to tkellem, #{@username}. If you already have an account and were trying to connect, please check your username, as it wasn't recognized."
        say_as_tkellem "Otherwise, follow these instructions to create an account."
        say_as_tkellem ' '
        if recaptcha = Setting.get('recaptcha_api_key').presence
          @state = :recaptcha
          require 'tkellem/plugins/recaptcha'
          @recaptcha = Recaptcha.new(*recaptcha.split(',', 2))
          say_as_tkellem "First, you'll need to take a captcha test to verify that you aren't an evil robot bent on destroying humankind."
          say_as_tkellem "Visit this URL, and tell me the code you are given after solving the captcha: #{@recaptcha.challenge_url}"
          return
        end
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
    trace "to client: #{msg}"
    if !tags && msg.is_a?(IrcMessage) && !msg.tags.empty?
      msg = msg.dup
      msg.tags = {}
    end
    send_data("#{msg}\r\n")
  end

  def unbind
    failsafe(:unbind) do
      @bouncer.disconnect_client(self) if @bouncer
    end
  end
end

end
