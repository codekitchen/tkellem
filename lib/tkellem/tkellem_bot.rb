require 'shellwords'

module Tkellem

class TkellemBot
  def self.run_command(line, &block)
    args = Shellwords.shellwords(line)
    case command = args.shift.downcase
    when "help"
      yield "tkellem admin interface"
      yield "available commands:"
      yield "listen"
    when "listen"
      listen(args, &block)
    else
      yield "Unknown command: #{command}"
    end
  end

  def self.listen(args)
    command = args.shift.downcase
    address, port = (args.shift || '').split(':', 2)

    case command
    when "add"
      ssl = %w(ssl true t y yes).include?(args.shift)
      addr = ListenAddress.create(:address => address, :port => port, :ssl => ssl)
      if addr.errors.any?
        yield "Error adding new listen address:"
        addr.errors.full_messages.each { |m| yield "  #{m}" }
      else
        yield "New listen address #{addr}"
      end
    when "remove"
      addr = ListenAddress.find_by_address_and_port(address, port)
      addr.destroy
      yield "Stopped listening on #{addr}"
    when "list"
      yield "Listening:"
      ListenAddress.all.each do |addr|
        yield "  #{addr}"
      end
    else
      yield "Uknown sub-command for listen: #{command}. Available commands: add remove list"
    end
  end
end

end
