module Tkellem

class IrcLine
  RE = %r{(:[^ ]+ )?([^ ]*)(.*)}i

  def self.parse(line)
    md = RE.match(line) or raise("invalid input: #{line.inspect}")

    self.new(line, md[1], md[2], md[3])
  end

  attr_reader :prefix, :command, :args

  def initialize(orig, prefix, command, args)
    @orig = orig
    @prefix = prefix ? prefix.strip : nil
    @command = command

    args.strip!
    idx = args.index(":")
    if idx
      @args = args[0...idx].split(' ') + [args[idx+1..-1]]
    else
      @args = args.split(' ')
    end
  end

  def command?(cmd)
    @command.downcase == cmd.downcase
  end

  def replay
    @orig
  end
  alias_method :to_s, :replay

  def last
    args.last
  end

  def with_timestamp(timestamp)
    new_command = [prefix, command]
    new_command += args[0..-2]
    new_command.push("#{timestamp.strftime("%H:%M:%S")}> #{args.last}")
    new_command.join(' ')
  end

end

end
