require 'eventmachine'
require 'active_record'

require 'tkellem/bouncer_connection'
require 'tkellem/bouncer'

require 'tkellem/models/user'
require 'tkellem/models/network'
require 'tkellem/models/host'
require 'tkellem/models/network_user'
require 'tkellem/models/listen_address'

require 'tkellem/plugins/push_service'
require 'tkellem/plugins/backlog'

module Tkellem

class TkellemServer
  include Tkellem::EasyLogger

  def initialize(config)
    @listeners = []
    @bouncers = {}

    ActiveRecord::Base.establish_connection({
      :adapter => 'sqlite3',
      :database => File.expand_path("~/.tkellem/tkellem.sqlite3"),
    })
    ActiveRecord::Migrator.migrate(File.expand_path("../migrations", __FILE__), nil)

    ListenAddress.all.each { |a| listen(a) }
    NetworkUser.find_each { |nu| add_bouncer(Bouncer.new(nu)) }
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
  end

  def find_bouncer(user, network_name)
    key = [user.id, network_name]
    @bouncers[key]
  end
end

end
