module Tkellem

class IrcLine < Struct.new(:prefix, :command, :args, :ext_arg)
  RE = %r{(:[^ ]+ )?([^ ]*)(.*)}i

  def self.parse(line)
    md = RE.match(line) or raise("invalid input: #{line.inspect}")

    prefix = md[1] && md[1][1..-1].strip
    command = md[2]
    args = md[3]
    ext_arg = nil

    args.strip!
    idx = args.index(":")
    if idx
      args, ext_arg = args[0...idx].split(' '), args[idx+1..-1]
    else
      args = args.split(' ')
    end

    self.new(prefix, command, args, ext_arg)
  end

  def command?(cmd)
    @command.downcase == cmd.downcase
  end

  def replay
    line = []
    line << ":#{prefix}" unless prefix.nil?
    line << command
    line += args
    line << ":#{ext_arg}" unless ext_arg.nil?
    line.join ' '
  end
  alias_method :to_s, :replay

  def last
    ext_arg || args.last
  end

  def target_user
    if prefix && md = %r{^([^!]+)}.match(prefix)
      md[1]
    else
      nil
    end
  end

  def with_timestamp(timestamp)
    new_ext_arg = ext_arg && "#{timestamp.strftime("%H:%M:%S")}> #{ext_arg}"
    IrcLine.new(prefix, command, args, new_ext_arg)
  end

end

end
