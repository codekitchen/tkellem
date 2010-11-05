require 'eventmachine'

require 'tkellem/irc_server'

module Tkellem
  class Bouncer
    def initialize(listen_address, port, do_ssl)
      @irc_servers = {}
      @server = EM.start_server(listen_address, port, BouncerConnection,
                                self, do_ssl)
    end

    def add_irc_server(name, host, port, do_ssl, nick)
      @irc_servers[name] = EM.connect(host, port, IrcServer, self, name, do_ssl, nick)
    end

    def on_authenticate(&block)
      @auth_block = block
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
