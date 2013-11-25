# encoding: utf-8
require 'backwards_file_reader'
require 'fileutils'
require 'geoip'
require 'pathname'
require 'time'

require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/time'

require 'tkellem/irc_message'
require 'tkellem/tkellem_bot'

module Tkellem

# The default backlog handler. Stores messages, and allows for
# device-independent backlogs (if the client sends a device_name, that device
# will get its own backlog cursor).

# This is implemented as a plugin -- in theory, it could be switched out for a
# different backlog implementation. Right now, it's always loaded though.
class Backlog
  include Tkellem::EasyLogger

  Bouncer.add_plugin(self)
  SERVER_TIME_CAPS = %w{server-time znc.in/server-time-iso}.freeze
  BouncerConnection.register_tag_cap(*SERVER_TIME_CAPS)
  cattr_accessor :instances

  def self.get_instance(bouncer)
    bouncer.data(self)[:instance] ||= self.new(bouncer, bouncer.path)
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

  #### IMPL

  def self.geoip(conn)
    if !defined?(@geoip)
      begin
        @geoip = GeoIP.new('/usr/share/GeoIP/GeoIPCity.dat')
      rescue Errno::ENOENT
        @geoip = nil
      end
    end
    geoip_info = @geoip && @geoip.country(Socket.unpack_sockaddr_in(conn.get_peername).last)
    tz = geoip_info.respond_to?(:timezone) && geoip_info.timezone && ActiveSupport::TimeZone[geoip_info.timezone]
    country = geoip_info.respond_to?(:country_code2) && geoip_info.country_code2
    [tz, country]
  end

  class Device < Struct.new(:network_user, :device_name, :positions, :time_zone, :country)
    def initialize(*a)
      super
      self.positions = {}
    end

    def update_pos(ctx_name, pos)
      # TODO: it'd be a good idea to throttle these updates to once every few seconds per ctx
      # right now we're kind of harsh on the sqlite db
      self.position(ctx_name).first_or_create.update_attribute(:position, pos)
    end

    def pos(ctx_name, pos_for_new = 0)
      backlog_pos = self.position(ctx_name).first_or_initialize
      if backlog_pos.new_record?
        backlog_pos.position = pos_for_new
        backlog_pos.save
      end
      backlog_pos.position
    end

    protected

    def position(ctx_name)
      self.positions[ctx_name] ||=
        BacklogPosition.where(:network_user_id => network_user.id,
                              :context_name    => ctx_name,
                              :device_name     => device_name)
    end
  end

  def initialize(bouncer, path = "~/.tkellem")
    @bouncer = bouncer
    @network_user = bouncer.network_user
    @devices = {}
    @dir = Pathname.new(File.join(path, "logs/#{bouncer.user.username}/#{bouncer.network.name}"))
    @dir.mkpath()
  end

  def stream_path(ctx)
    @dir + "#{ctx}.log"
  end

  def all_existing_ctxs
    @dir.entries.select { |e| e.extname == ".log" }.map { |e| e.basename(".log").to_s }
  end

  def get_stream(ctx, for_reading = false)
    mode = for_reading ? 'rb:utf-8' : 'ab:utf-8'
    ctx = ctx.gsub(%r{[\./\\]}, '')
    path = stream_path(ctx)
    return nil if !path.file? && for_reading
    path.open(mode) do |stream|
      if !for_reading
        stream.seek(0, IO::SEEK_END)
      end
      yield stream
    end
  end

  def stream_size(ctx)
    stream_path(ctx).size
  end

  def get_device(conn)
    @devices[conn.device_name] ||= Device.new(@network_user, conn.device_name)
  end

  def client_connected(conn)
    device = get_device(conn)
    tz, country = self.class.geoip(conn)
    device.time_zone = tz || device.time_zone
    device.country = country || device.country
    behind = all_existing_ctxs.select do |ctx_name|
      eof = stream_size(ctx_name)
      # default to the end of file, rather than the beginning, for new devices
      # that way they don't get flooded the first time they connect
      device.pos(ctx_name, eof) < eof
    end
    if !behind.empty?
      # this device has missed messages, replay all the relevant backlogs
      send_connect_backlogs(conn, device, behind)
    end
  end

  def update_pos(ctx_name, pos)
    # don't just iterate @devices here, because that may contain devices that
    # have since been disconnected
    @bouncer.active_conns.each do |conn|
      device = get_device(conn)
      device.update_pos(ctx_name, pos)
    end
  end

  def log_name
    "backlog:#{@bouncer.log_name}"
  end

  def now_timestamp
    Time.now.utc.iso8601(3)
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
      msg.tags[:time] ||= now_timestamp
      write_msg(ctx, "#{now_timestamp} < #{'* ' if msg.action?}#{msg.prefix}: #{msg.args.last}")
    end
  end

  def client_msg(msg)
    case msg.command
    when 'PRIVMSG'
      return if msg.ctcp? && !msg.action?
      ctx = msg.args.first
      write_msg(ctx, "#{now_timestamp} > #{'* ' if msg.action?}#{msg.args.last}")
    end
  end

  def write_msg(ctx, processed_msg)
    get_stream(ctx) do |stream|
      stream.puts(processed_msg)
      update_pos(ctx, stream.pos)
    end
  end

  def send_connect_backlogs(conn, device, contexts)
    contexts.each do |ctx_name|
      start_pos = device.pos(ctx_name)
      get_stream(ctx_name, true) do |stream|
        stream.seek(start_pos)
        send_backlog(conn, ctx_name, stream, device.time_zone)
        device.update_pos(ctx_name, stream.pos)
      end
    end
  end

  def send_backlog_since(conn, start_time, contexts)
    debug "scanning for backlog from #{start_time.iso8601(3)}"
    contexts.each do |ctx_name|
      get_stream(ctx_name, true) do |stream|
        last_line_len = 0
        BackwardsFileReader.scan(stream) do |line|
          # remember this last line length so we can scan past it
          last_line_len = line.length
          timestamp, _ = (self.class.parse_line(line, nil, timestamp_only: true) rescue [nil, nil])
          !timestamp || timestamp >= start_time
        end
        stream.seek(last_line_len, IO::SEEK_CUR)
        send_backlog(conn, ctx_name, stream, get_device(conn).time_zone)
      end
    end
  end

  def send_backlog(conn, ctx_name, stream, time_zone)
    while line = stream.gets
      timestamp, msg = self.class.parse_line(line, ctx_name)
      next unless msg
      msg.readdress_to(@bouncer.nick)
      if !(conn.caps & SERVER_TIME_CAPS).empty?
        msg.tags[:time] = timestamp.utc.iso8601(3)
      else
        timestamp = timestamp.in_time_zone(time_zone) if timestamp && time_zone
        timestamp = timestamp.localtime if timestamp && !time_zone
        msg = msg.with_timestamp(timestamp)
      end
      conn.send_msg(msg)
    end
  end

  def self.parse_line(line, ctx_name, options = {})
    space = line.index(' ')
    timestamp = Time.parse(line[0, space])
    if options[:timestamp_only]
      return timestamp, nil
    end

    case line[space + 1..-1]
    when %r{^> (\* )?(.+)$}
      msg = IrcMessage.new(nil, 'PRIVMSG', [ctx_name, $2])
      if $1 == '* '
        msg.ctcp = 'ACTION'
      end
      return timestamp, msg
    when %r{^< (\* )?([^ ]+): (.+)$}
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

class BacklogCommand < TkellemBot::Command
  register 'backlog'

  def self.admin_only?
    false
  end

  def execute
    hour_str = args.pop
    hours = hour_str.to_f
    hours *= 24 if hour_str && hour_str[-1] == 'd'[-1]
    hours = 1 if hours <= 0 || hours >= (24*365)
    cutoff = hours.hours.ago
    backlog = Backlog.get_instance(bouncer)
    rooms = [args.pop].compact
    if rooms.empty?
      rooms = backlog.all_existing_ctxs
    end
    backlog.send_backlog_since(conn, cutoff, rooms)
  end
end

class TimezoneCommand < TkellemBot::Command
  register 'timezone'

  def self.admin_only?
    false
  end

  def execute
    backlog = Backlog.get_instance(bouncer)
    device = backlog.get_device(conn)

    if !args.empty?
      arg = args.join(' ')
      tz = ActiveSupport::TimeZone[arg]
      if !tz
        conn.say_as_tkellem "Unknown time zone '#{arg}'; please use an IANA time zone"
        return
      end
      device.time_zone = tz
    end

    if !device.time_zone
      conn.say_as_tkellem "<time zone not set; using #{Time.now.zone}>"
      return
    end

    # try to find a friendlier name to show the user
    begin
      country_zone = TZInfo::Country.get(device.country).zone_info.detect { |z| z.identifier == device.time_zone.name }
      if country_zone
        conn.say_as_tkellem country_zone.description_or_friendly_identifier
        return
      end
    rescue TZInfo::InvalidCountryCode
    end

    conn.say_as_tkellem device.time_zone.tzinfo.friendly_identifier
  end
end

end
