require 'eventmachine'

require 'tkellem/tkellem_bot'

module Tkellem

# listens on the unix domain socket and executes admin commands
module SocketServer
  include EM::Protocols::LineText2
  include Tkellem::EasyLogger

  def log_name
    "admin"
  end

  def post_init
    set_delimiter "\n"
  end

  def receive_line(line)
    trace "admin socket: #{line}"
    TkellemBot.run_command(line, nil) do |output|
      send_data("#{output}\n")
    end
    send_data("\0\n")
  rescue => e
    send_data("Error running command: #{e}\n")
    e.backtrace.each { |l| send_data("#{l}\n") }
    send_data("\0\n")
  end
end

end
