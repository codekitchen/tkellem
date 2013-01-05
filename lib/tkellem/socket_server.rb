require 'celluloid/io'

require 'tkellem/tkellem_bot'

module Tkellem

# listens on the unix domain socket and executes admin commands
# TODO: rename this class
class SocketServer
  include Celluloid::IO
  include Tkellem::EasyLogger
  include Tkellem::CelluloidTools::LineReader

  def log_name
    "admin"
  end

  def initialize(socket)
    @socket = socket
    @delimiter = "\n"
    run!
  end

  def receive_line(line)
    trace "admin socket: #{line}"
    TkellemBot.run_command(line, nil, nil) do |outline|
      send_data("#{outline}\n")
    end
    send_data("\0\n")
  rescue => e
    send_data("Error running command: #{e}\n")
    e.backtrace.each { |l| send_data("#{l}\n") }
    send_data("\0\n")
  end

  def send_data(dat)
    @socket.write(dat)
  end
end

end
