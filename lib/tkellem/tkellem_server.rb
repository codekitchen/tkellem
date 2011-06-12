require 'eventmachine'

require 'tkellem/bouncer_connection'
require 'tkellem/bouncer'
require 'tkellem/models/user'
require 'tkellem/models/network'
require 'tkellem/models/network_user'
require 'tkellem/models/listen_address'

require 'tkellem/plugins/push_service'

module Tkellem
class TkellemServer
  include Tkellem::EasyLogger

  def initialize
    @listeners = []
    @bouncers = {}
    ListenAddress.all.each { |a| listen(a) }
    add_bouncer(Bouncer.new(NetworkUser.new(User.new('test1'), Network.new)))
    add_bouncer(Bouncer.new(NetworkUser.new(User.new('brian'), Network.new)))
  end

  def listen(listen_address)
    address = listen_address.address
    port = listen_address.port
    ssl = listen_address.ssl

    info "Listening on #{address}:#{port} (ssl=#{!!ssl.inspect})"

    @listeners << EM.start_server(listen_address.address,
                                  listen_address.port,
                                  BouncerConnection,
                                  self,
                                  listen_address.ssl)
  end

  def add_bouncer(bouncer)
    key = [bouncer.user.id, bouncer.network.name]
    raise("bouncer already exists: #{key}") if @bouncers.include?(key)
    @bouncers[key] = bouncer
    # raise("server already exists: #{name}") if @irc_servers[name]
    # server = IrcServer.new(self, name, nick)
    # server.add_host(host, port, do_ssl)
    # @irc_servers[name] = server
    # server.set_max_backlog(@max_backlog) if @max_backlog
    # server
  end

  def find_bouncer(user, network_name)
    key = [user.id, network_name]
    @bouncers[key]
  end

  # def remove_irc_server(name)
  #   server = @irc_servers.delete(name)
  #   if server
  #     server.close_connection(true)
  #   end
  # end

  # def on_authenticate(&block)
  #   @auth_block = block
  # end

  # def max_backlog=(max_backlog)
  #   @max_backlog = max_backlog && max_backlog > 0 ? max_backlog : nil
  #   @irc_servers.each { |name, server| server.set_max_backlog(@max_backlog) }
  # end


  # Internal API

  # def get_irc_server(name) #:nodoc:
  #   @irc_servers[name]
  # end

  # def do_auth(username, password, irc_server) #:nodoc:
  #   if @auth_block
  #     @auth_block.call(username, password.to_s, irc_server)
  #   else
  #     true
  #   end
  # end
end
end
