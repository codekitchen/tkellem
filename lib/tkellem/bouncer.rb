require 'tkellem/irc_server'
require 'tkellem/bouncer_connection'
require 'tkellem/push_service'

module Tkellem

class Bouncer
  include Tkellem::EasyLogger

  attr_reader :user, :network, :nick

  def initialize(network_user)
    @network_user = network_user
    @user = network_user.user
    @network = network_user.network

    @nick = network_user.nick
    # maps { client_conn => state_hash }
    @active_conns = {}
    @backlog = Backlog.new
    @welcomes = []
    @rooms = ['#tk']
    # maps { client_conn => away_status_or_nil }
    @away = {}

    @hosts = network_user.network.hosts.map { |h| h }
    connect!
  end

  def connected?
    !!@connected
  end

  # pass nil device_name to use the default backlog
  # pass a device_name to have device-independent backlogs
  def connect_client(client, device_name)
    @active_conns[client] = {}
    @backlog.add_client(client, device_name)
    @away[client] = nil

    send_welcome(client)
    # send_backlog
    @rooms.each { |room| client.simulate_join(room) }

    check_away_status
  end

  def disconnect_client(client)
    @backlog.remove_client(client)
    @away.delete(client)
    check_away_status
    @active_conns.delete(client)
  end

  def client_msg(client, msg)
    forward = case msg.command
    when 'PING'
      client.send_msg(":tkellem!tkellem PONG tkellem :#{msg.args.last}")
      false
    when 'AWAY'
      @away[bouncer_conn] = msg.args.last
      check_away_status
      false
    when 'PUSH'
      PushService.client_msg(self, client, msg)
      false
    else
      true
    end

    if forward
      # send to server
      send_msg(msg)
    end
  end

  def server_msg(msg)
    forward = case msg.command
    when /0\d\d/, /2[56]\d/, /37[256]/
      @welcomes << msg
      ready! if msg.command == "376" # end of MOTD
      false
    when 'JOIN'
      debug "#{msg.target_user} joined #{msg.args.last}"
      @rooms << msg.args.last if msg.target_user == @nick
      true
    when 'PART'
      debug "#{msg.target_user} left #{msg.args.last}"
      @rooms.delete(msg.args.last) if msg.target_user == @nick
      true
    when 'PING'
      send_msg("PONG tkellem!tkellem :#{msg.args.last}")
      false
    when 'PONG'
      # swallow it, we handle ping-pong from clients separately, in
      # BouncerConnection
      false
    else
      true
    end

    if forward
      # send to clients
      @active_conns.each { |c,s| c.send_msg(msg) }
      # store to backlog
      @backlog.handle_message(msg)
    end
    PushService.server_msg(msg)
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
    trace "to server: #{msg}"
    @conn.send_data("#{msg}\r\n")
  end

  def connection_established
    # TODO: support sending a real username, realname, etc
    send_msg("USER #{@nick} localhost blah :#{@nick}")
    change_nick(@nick, true)
    check_away_status
  end

  def disconnected!
    debug "OMG we got disconnected."
    @conn = nil
    @connected = false
    @active_conns.each { |c,s| c.unbind }
    connect!
  end

  protected

  def change_nick(new_nick, force = false)
    return if !force && new_nick == @nick
    @nick = new_nick
    send_msg("NICK #{new_nick}")
  end

  def send_welcome(bouncer_conn)
    @welcomes.each { |msg| bouncer_conn.send_msg(msg) }
  end

  def connect!
    span = @last_connect ? Time.now - @last_connect : 1000
    if span < 5
      EM.add_timer(5) { connect! }
      return
    end
    @last_connect = Time.now
    @cur_host = (@cur_host || 0) % @hosts.length
    host = @hosts[@cur_host]
    @conn = EM.connect(host.address, host.port, IrcServerConnection, self, host.ssl)
  end

  def ready!
    return if @joined_rooms
    @joined_rooms = true
    @rooms.each do |room|
      send_msg("JOIN #{room}")
    end

    # We're all initialized, allow connections
    @connected = true
  end

end

end
