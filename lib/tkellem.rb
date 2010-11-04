begin
  require 'rubygems'
rescue LoadError
end
require 'eventmachine'

pathname = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push(pathname) unless $LOAD_PATH.include?(pathname)

require 'tkellem/irc_server'

module Tkellem
  class Bouncer
    def initialize(listen_address, port, do_ssl)
      unless EM.reactor_running?
        Thread.new { EM.run { } }
      end

      @irc_servers = {}
      @server = EM.start_server(listen_address, port, BouncerConnection,
                                self, do_ssl)
    end

    def add_irc_server(name, host, port, do_ssl, nick)
      EM.connect(host, port, IrcServer, self, name, do_ssl, nick)
    end

    def irc_server_ready(irc_server)
      @irc_servers[irc_server.name] = irc_server
    end

    def get_irc_server(name)
      @irc_servers[name]
    end

    def on_authenticate(&block)
      @auth_block = block
    end

    def do_auth(username, password, irc_server)
      if @auth_block
        @auth_block.call(username, password.to_s, irc_server)
      else
        true
      end
    end
  end
end
