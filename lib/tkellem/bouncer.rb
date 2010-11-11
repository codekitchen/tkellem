require 'eventmachine'

require 'tkellem/irc_server'

module Tkellem
  class Bouncer
    def initialize(listen_address, port, do_ssl)
      @irc_servers = {}
      @max_backlog = nil
      @server = EM.start_server(listen_address, port, BouncerConnection,
                                self, do_ssl)
    end

    def add_irc_server(name, host, port, do_ssl, nick)
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
