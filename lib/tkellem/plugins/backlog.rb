require 'fileutils'
require 'time'

require 'active_support/core_ext/class/attribute_accessors'

require 'tkellem/irc_message'

module Tkellem

# The default backlog handler. Stores messages, and allows for
# device-independent backlogs (if the client sends a device_name, that device
# will get its own backlog cursor).

# This is implemented as a plugin -- in theory, it could be switched out for a
# different backlog implementation. Right now, it's always loaded though.
class Backlog
  include Tkellem::EasyLogger
  include Celluloid

  cattr_accessor :replay_pool

  Bouncer.add_plugin(self)

  def self.get_instance(bouncer)
    bouncer.data(self)[:instance] ||= self.new(bouncer)
  end

  def self.new_client_connected(bouncer, client)
    instance = get_instance(bouncer)
    instance.client_connected(client)
  end

  def self.client_msg(bouncer, client, msg)
    instance = get_instance(bouncer)
    instance.client_msg(msg)
    true
  end

  def self.server_msg(bouncer, msg)
    instance = get_instance(bouncer)
    instance.server_msg(msg)
    true
  end

  def initialize(bouncer)
    @bouncer = bouncer
    @devices = {}
    @streams = {}
    @starting_pos = {}
    @dir = File.expand_path("~/.tkellem/logs/#{bouncer.user.username}/#{bouncer.network.name}")
    FileUtils.mkdir_p(@dir)
  end

  def stream_filename(ctx)
    File.join(@dir, "#{ctx}.log")
  end

  def get_stream(ctx)
    # open stream in append-only mode
    return @streams[ctx] if @streams[ctx]
    stream = @streams[ctx] = File.open(stream_filename(ctx), 'ab')
    stream.seek(0, ::IO::SEEK_END)
    @starting_pos[ctx] = stream.pos
    stream
  end

  def get_device(conn)
    @devices[conn.device_name] ||= Hash.new { |h,k| h[k] = @starting_pos[k] }
  end

  def client_connected(conn)
    device = get_device(conn)
    if @streams.any? { |ctx_name, stream| device[ctx_name] < stream.pos }
      # this device has missed messages, replay all the backlogs
      send_backlog(conn, device)
    end
  end

  def update_pos(ctx_name, pos)
    @bouncer.active_conns.each do |conn|
      device = get_device(conn)
      device[ctx_name] = pos
    end
  end

  def log_name
    "backlog:#{@bouncer.log_name}"
  end

  def server_msg(msg)
    case msg.command
    when /3\d\d/, 'JOIN', 'PART'
      # transient messages
      return
    when 'PRIVMSG'
      return if msg.ctcp? && !msg.action?
      ctx = msg.args.first
      if ctx == @bouncer.nick
        # incoming pm, fake ctx to be the sender's nick
        ctx = msg.prefix.split(/[!~@]/, 2).first
      end
      stream = get_stream(ctx)
      stream.puts(Time.now.strftime("%d-%m-%Y %H:%M:%S") + " < #{'* ' if msg.action?}#{msg.prefix}: #{msg.args.last}")
      update_pos(ctx, stream.pos)
    end
  end

  def client_msg(msg)
    case msg.command
    when 'PRIVMSG'
      return if msg.ctcp? && !msg.action?
      ctx = msg.args.first
      stream = get_stream(ctx)
      stream.puts(Time.now.strftime("%d-%m-%Y %H:%M:%S") + " > #{'* ' if msg.action?}#{msg.args.last}")
      update_pos(ctx, stream.pos)
    end
  end

  def send_backlog(conn, device)
    device.each do |ctx_name, pos|
      filename = stream_filename(ctx_name)
      Backlog.replay_pool.async(:replay, filename, pos, @bouncer, conn, ctx_name)
      device[ctx_name] = get_stream(ctx_name).pos
    end
  end
end

class BacklogReplay
  include Celluloid

  def replay(filename, pos, bouncer, conn, ctx_name)
    stream = File.open(filename, 'rb')
    stream.seek(pos)

    while line = stream.gets
      timestamp, msg = parse_line(line, ctx_name)
      puts msg
      puts msg.inspect
      next unless msg
      privmsg = msg.args.first[0] != '#'[0]
      if msg.prefix
        # to this user
        if privmsg
          msg.args[0] = bouncer.nick
        else
          # do nothing, it's good to send
        end
      else
        # from this user, maybe add prefix
        if privmsg
          # a one-on-one chat -- every client i've seen doesn't know how to
          # display messages from themselves here, so we fake it by just
          # adding an arrow and pretending the other user said it. shame.
          msg.prefix = msg.args.first
          msg.args[0] = bouncer.nick
          msg.args[-1] = "-> #{msg.args.last}"
        else
          # it's a room, we can just replay
          msg.prefix = bouncer.nick
        end
      end
      conn.send_msg(msg.with_timestamp(timestamp))
    end
  end

  def parse_line(line, ctx_name)
    timestamp = Time.parse(line[0, 19])
    case line[20..-1]
    when %r{^> (\* )?(.+)$}
      msg = IrcMessage.new(nil, 'PRIVMSG', [ctx_name, $2])
      if $1 == '* '
        msg.ctcp = 'ACTION'
      end
      return timestamp, msg
    when %r{^< (\* )?([^:]+): (.+)$}
      msg = IrcMessage.new($2, 'PRIVMSG', [ctx_name, $3])
      if $1 == '* '
        msg.ctcp = 'ACTION'
      end
      return timestamp, msg
    else
      nil
    end
  end
end

Backlog.replay_pool = BacklogReplay.pool(size: Celluloid.cores * 2)

end
