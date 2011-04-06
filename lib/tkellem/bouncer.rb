require 'eventmachine'

require 'tkellem/irc_server'

module Tkellem
  class Bouncer
    def initialize
      @irc_servers = {}
      @listeners = {}
      @max_backlog = nil
    end

    def listen(address, port, do_ssl)
      @listeners[[address, port]] = EM.start_server(address,
                                                    port, BouncerConnection,
                                                    self, do_ssl)
    end

    def stop_listening(address, port)
      if server = @listeners[[address, port]]
        EM.stop_server(server)
      end
    end

    def add_irc_server(name, host, port, do_ssl, nick)
      raise("server already exists: #{name}") if @irc_servers[name]
      server = EM.connect(host, port, IrcServer, self, name, do_ssl, nick)
      @irc_servers[name] = server
      server.set_max_backlog(@max_backlog) if @max_backlog
      server
    end

    def remove_irc_server(name)
      server = @irc_servers.delete(name)
      if server
        server.close_connection(true)
      end
    end

    def on_authenticate(&block)
      @auth_block = block
    end

    def max_backlog=(max_backlog)
      @max_backlog = max_backlog && max_backlog > 0 ? max_backlog : nil
      @irc_servers.each { |name, server| server.set_max_backlog(@max_backlog) }
    end


    # Internal API

    def get_irc_server(name) #:nodoc:
      @irc_servers[name]
    end

    def do_auth(username, password, irc_server) #:nodoc:
      if @auth_block
        @auth_block.call(username, password.to_s, irc_server)
      else
        true
      end
    end
  end
end
