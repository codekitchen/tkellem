module Tkellem

class IrcMessage < Struct.new(:prefix, :command, :args)
  RE = %r{(:[^ ]+ )?([^ ]*)(.*)}i

  def self.parse(line)
    md = RE.match(line) or raise("invalid input: #{line.inspect}")

    prefix = md[1] && md[1][1..-1].strip
    command = md[2]
    args = md[3]

    args.strip!
    idx = args.index(":")
    if idx
      args = args[0...idx].split(' ') + [args[idx+1..-1]]
    else
      args = args.split(' ')
    end

    self.new(prefix, command, args)
  end

  def command?(cmd)
    @command.downcase == cmd.downcase
  end

  def replay
    line = []
    line << ":#{prefix}" unless prefix.nil?
    line << command
    ext_arg = args.last if args.last && args.last.match(%r{\s})
    line += ext_arg ? args[0...-1] : args
    line << ":#{ext_arg}" unless ext_arg.nil?
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
    args = self.args
    if args && args[-1]
      args = args.dup
      args[-1] = "#{timestamp.strftime("%H:%M:%S")}> #{args[-1]}"
    end
    IrcMessage.new(prefix, command, args)
  end

end

end
