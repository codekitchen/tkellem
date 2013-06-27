# encoding: utf-8
module Tkellem

class IrcMessage < Struct.new(:prefix, :command, :args, :ctcp)
  RE = %r{(:[^ ]+ )?([^ ]*)(.*)}i

  def self.parse(line)
    md = RE.match(line) or raise("invalid input: #{line.inspect}")

    prefix = md[1] && md[1][1..-1].strip
    command = md[2].upcase
    args = md[3]

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

  def ctcp?
    self.ctcp.present?
  end

  def action?
    self.ctcp == 'ACTION'
  end

  def replay
    line = []
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

end

end
