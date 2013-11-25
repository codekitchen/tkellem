# encoding: utf-8

require 'active_support/core_ext/time'

module Tkellem

class IrcMessage < Struct.new(:prefix, :command, :args, :ctcp, :tags)
  RE = %r{(?:@([^ ]*) )?(:[^ ]+ )?([^ ]*)(.*)}i

  def self.parse(line)
    md = RE.match(line) or raise("invalid input: #{line.inspect}")

    tags = md[1]
    prefix = md[2] && md[2][1..-1].strip
    command = md[3].upcase
    args = md[4]

    args.strip!
    idx = args.index(":")
    if idx && (idx == 0 || args[idx-1] == " "[0])
      args = args[0...idx].split(' ') + [args[idx+1..-1]]
    else
      args = args.split(' ')
    end

    msg = self.new(prefix, command, args)

    if args.last && args.last.match(%r{#{"\x01"}([^ ]+)([^\1]*)#{"\x01"}})
      msg.ctcp = $1.upcase
      msg.args[-1] = $2.strip
    end

    if tags
      msg.tags = Hash[tags.split(';').map { |tag| tag.split('=') }]
    end

    msg
  end

  # parse a command as it'd come from a client, e.g.
  # /nick newnick
  #   or
  # /msg #someroom hey guys
  def self.parse_client_command(line)
    return nil unless line[0] == '/'[0]
    if line =~ %r{^/msg\s+(\S+)\s+(.*)$}
      line = "/PRIVMSG #{$1} :#{$2}"
    end
    msg = parse(line[1..-1])
    return nil unless msg
    msg
  end

  def initialize(*args)
    super
    self.tags ||= {}
    self.args ||= []
  end

  def ctcp?
    self.ctcp.present?
  end

  def action?
    self.ctcp == 'ACTION'
  end

  def replay
    line = []

    if !tags.empty?
      line << "@#{tags.map { |k, v| v.nil? ? k : "#{k}=#{v}"}.join(';') }"
    end
    line << ":#{prefix}" unless prefix.nil?
    line << command
    ext_arg = args.last if args.last && args.last.match(%r{^:|\s})
    line += ext_arg ? args[0...-1] : args
    if ctcp?
      line << ":\x01#{ctcp} #{ext_arg}\x01"
    else
      line << ":#{ext_arg}" unless ext_arg.nil?
    end
    line.join ' '
  end
  alias_method :to_s, :replay

  def target_user
    if prefix && md = %r{^([^!]+)}.match(prefix)
      md[1]
    else
      nil
    end
  end

  def with_timestamp(timestamp)
    if timestamp <= 24.hours.ago
      timestring = timestamp.strftime("%Y-%m-%d %H:%M:%S")
    else
      timestring = timestamp.strftime("%H:%M:%S")
    end
    args = self.args
    if args && args[-1]
      args = args.dup
      args[-1] = "#{timestring}> #{args[-1]}"
    end
    IrcMessage.new(prefix, command, args, ctcp)
  end

  def readdress_to(nick)
    privmsg = args.first[0] != '#'[0]

    if prefix
      # to this user
      if privmsg
        args[0] = nick
      else
        # do nothing, it's good to send
      end
    else
      # from this user
      if privmsg
        # a one-on-one chat -- every client i've seen doesn't know how to
        # display messages from themselves here, so we fake it by just
        # adding an arrow and pretending the other user said it. shame.
        self.prefix = args.first
        args[0] = nick
        args[-1] = "-> #{args.last}"
      else
        # it's a room, we can just replay
        self.prefix = nick
      end
    end
  end
end

end
