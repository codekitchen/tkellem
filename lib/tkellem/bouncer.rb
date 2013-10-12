# encoding: utf-8
require 'active_support/core_ext/class/attribute_accessors'

require 'tkellem/irc_server'
require 'tkellem/bouncer_connection'

module Tkellem

class Bouncer
  include Tkellem::EasyLogger

  attr_reader :user, :network, :nick, :network_user, :connected_at
  cattr_accessor :plugins
  self.plugins = []

  def initialize(network_user)
    @network_user = network_user
    @user = network_user.user
    @network = network_user.network

    @nick = network_user.nick
    # maps { client_conn => state_hash }
    @active_conns = {}
    @welcomes = []
    @rooms = Room.where(network_user_id: network_user.id).each_with_object({}) { |room,h| h[room.name] = room }
    # maps { client_conn => away_status_or_nil }
    @away = {}
    # plugin data
    @data = {}
    # clients waiting for us to connect to the irc server
    @waiting_clients = []
    @awaiting_replies = {}

    connect!
  end

  def data(key)
    @data[key] ||= {}
  end

  def active_conns
    @active_conns.keys
  end

  def self.add_plugin(plugin)
    self.plugins << plugin
  end

  def connected?
    !!@connected
  end

  def connect_client(client)
    @active_conns[client] = {}
    @away[client] = nil

    if !connected?
      @waiting_clients << client
      client.say_as_tkellem("Connecting you to the IRC server. Please wait...")
      return
    end

    # force the client nick
    client.send_msg(":#{client.connecting_nick} NICK #{nick}") if client.connecting_nick != nick
    send_welcome(client)
    # make the client join all the rooms that we're in
    @rooms.each_value { |room| client.simulate_join(room) }

    plugins.each { |plugin| plugin.new_client_connected(self, client) }
    check_away_status
  end

  def disconnect_client(client)
    @away.delete(client)
    check_away_status
    @active_conns.delete(client)
  end

  def client_msg(client, msg)
    return if plugins.any? do |plugin|
      !plugin.client_msg(self, client, msg)
    end

    forward = case msg.command
    when 'PING'
      client.send_msg(":tkellem!tkellem PONG tkellem :#{msg.args.last}")
      false
    when 'AWAY'
      @away[client] = msg.args.last
      check_away_status
      false
    when 'NICK'
      @nick = msg.args.last
      true
    when 'WHO'
      client
    else
      true
    end

    if forward
      # send to server
      send_msg(msg)

      # replay to other connected clients
      if msg.command == "PRIVMSG" && (!msg.ctcp? || msg.action?)
        msg.readdress_to(nick)

        @active_conns.each do |c,s|
          next if c == client
          c.send_msg(msg)
        end
      end

      flag_for_reply(msg.command, forward) if forward != true
    end
  end

  def flag_for_reply(command, conn)
    @awaiting_replies[command] = conn
  end

  def server_msg(msg)
    return if plugins.any? do |plugin|
      !plugin.server_msg(self, msg)
    end

    forward = case msg.command
    when /0\d\d/, /2[56]\d/, /37[256]/
      @welcomes << msg
      ready! if msg.command == "376" # end of MOTD
      false
    when 'JOIN'
      room_name = msg.args.first
      if msg.target_user == @nick && !@rooms[room_name]
        room = Room.create!(network_user_id: network_user.id, name: room_name)
        @rooms[room_name] = room
      end
      true
    when 'PART'
      room_name = msg.args.first
      if msg.target_user == @nick
        room = @rooms.delete(room_name)
        room.destroy
      end
      true
    when 'TOPIC'
      if room = @rooms[msg.args.first]
        room.topic = msg.args.last
      end
    when '332' # topic replay
      if room = @rooms[msg.args[1]]
        room.topic = msg.args.last
      end
    when '333' # topic timestamp
      if room = @rooms[msg.args[1]]
        room.topic_setter = msg.args[2]
        room.topic_time = msg.args[3]
      end
    when 'PING'
      send_msg("PONG tkellem!tkellem :#{msg.args.last}")
      false
    when 'PONG'
      # swallow it, we handle ping-pong from clients separately, in
      # BouncerConnection
      false
    when '433'
      # nick already in use, try another
      change_nick("#{@nick}_")
      false
    when 'NICK'
      if msg.prefix == nick
        @nick = msg.args.last
      end
      true
    when '352'
      @awaiting_replies['WHO'] || true
    when '315'
      @awaiting_replies.delete('WHO') || true
    else
      true
    end

    if forward == true
      # send to clients
      @active_conns.each { |c,s| c.send_msg(msg) }
    elsif forward && @active_conns.include?(forward)
      forward.send_msg(msg)
    end
  end

  ## Away Statuses

  def check_away_status
    # for now we pretty much randomly pick an away status if multiple are set
    # by clients
    if @away.any? { |k,v| !v }
      # we have a client who isn't away
      send_msg("AWAY")
    else
      message = @away.values.first || "Away"
      send_msg("AWAY :#{message}")
    end
  end


  def name
    "#{user.name}-#{network.name}"
  end
  alias_method :log_name, :name

  def send_msg(msg)
    return unless @conn
    trace "to server: #{msg}"
    @conn.send_data("#{msg}\r\n")
  end

  def connection_established(conn)
    @conn = conn
    # TODO: support sending a real username, realname, etc
    send_msg("USER #{@user.username} somehost tkellem :#{@user.name}@tkellem")
    change_nick(@nick, true)
    @connected_at = Time.now
  end

  def disconnected!
    debug "OMG we got disconnected."
    @conn = nil
    @connected = false
    @connected_at = nil
    @active_conns.each { |c,s| c.close_connection }
    connect!
  end

  def kill!
    @active_conns.each { |c,s| c.close_connection }
  end

  protected

  def change_nick(new_nick, force = false)
    return if !force && new_nick == @nick
    @nick = new_nick
    send_msg("NICK #{new_nick}")
  end

  def send_welcome(bouncer_conn)
    @welcomes.each { |msg| msg.args[0] = nick; bouncer_conn.send_msg(msg) }
  end

  def connect!
    @connector ||= IrcServerConnection.connector(self, network)
    @connector.connect!
  end

  def ready!
    @rooms.each_value do |room|
      send_msg("JOIN #{room.name}")
    end

    check_away_status

    # We're all initialized, allow connections
    @connected_at = Time.now
    @connected = true

    @network_user.combined_at_connect.each do |line|
      msg = IrcMessage.parse_client_command(line)
      send_msg(msg) if msg
    end

    @waiting_clients.each do |client|
      client.say_as_tkellem("Now connected.")
      connect_client(client)
    end
    @waiting_clients.clear
  end

end

end
