require 'eventmachine'
require 'json'
require 'tkellem/irc_message'

module Tkellem

# http://colloquy.mobi/bouncers.html
class PushService
  include Tkellem::EasyLogger

  attr_reader :server, :port, :device_token

  def self.connections
    @connections || @connections = {}
  end

  def self.active_instances
    # TODO: need to time these out after some period -- a week or something
    @instances || @instances = {}
  end

  def self.client_msg(bouncer, client, msg)
    # TODO: check if push services enabled
    raise("only push plz") unless msg.command == 'PUSH'
    if service = client.data(self)[:instance]
      service.client_message(msg)
    elsif msg.args.first != 'add-device'
      # TODO: return error to client?
    else
      service = PushService.new(bouncer, msg)
      # This will replace the old one for the same device, if it exists
      active_instances[service.device_token] = service
      client.data(self)[:instance] = service
    end
  end

  def self.server_msg(msg)
    active_instances.each { |token, service| service.handle_message(msg) }
  end

  def self.stop_service(push_service)
    active_instances.delete(push_service.device_token)
  end

  def log_name
    "#{@bouncer.log_name}:#{@device_token}"
  end

  def initialize(bouncer, add_device_msg)
    @bouncer = bouncer
    @device_token, @device_name = add_device_msg.args[1,2]
  end

  def client_message(msg)
    raise("only push plz") unless msg.command == 'PUSH'
    case msg.args.first
    when 'add-device'
      # shouldn't get this again
    when 'service'
      @server, @port = msg.args[1,2].map { |a| a.downcase }
      ensure_connection
    when 'connection'
      # TODO: what's this for
    when 'highlight-word'
      # TODO: custom highlight words
    when 'highlight-sound'
      @highlight_sound = msg.args.last
    when 'message-sound'
      @message_sound = msg.args.last
    when 'end-device'
    when 'remove-device'
      self.class.stop_service(self)
    end
  end

  def handle_message(msg)
    return unless @connection
    case msg.command
    when /privmsg/i
      send_message(msg) if msg.args.last =~ /#{@bouncer.nick}/
    end
  end

  def send_message(msg)
    trace "forwarding #{msg} for #{@device_token}"
    sender = msg.prefix.split('!', 2).first
    room = msg.args.first

    args = {
      'device-token' => @device_token,
      'message' => msg.args.last.to_s,
      'sender' => sender,
      'room' => msg.args.first,
      'server' => 'blah',
      'badge' => 1,
    }
    args['sound'] = @message_sound if @message_sound
    @connection.send_data(args.to_json) if @connection
  end

  def ensure_connection
    @connection = self.class.connections[[@server, @port]] ||=
      EM.connect(@server, @port, PushServiceConnection, self, @server, @port)
  end

  def lost_connection
    self.class.connections.delete([@server, @port])
    @connection = nil
    ensure_connection
  end
end

module PushServiceConnection
  include Tkellem::EasyLogger

  def initialize(service, server, port)
    @service = service
    @server = server
    @port = port
  end

  def post_init
    start_tls :verify_peer => false
  end

  def log_name
    "#{@server}:#{@port}"
  end

  def ssl_handshake_completed
    debug "connected to push service #{@server}:#{@port}"
    @connected = true
  end

  def unbind
    debug "lost connection to push service #{@server}:#{@port}"
    @connected = false
    @service.lost_connection
  end
end

end
