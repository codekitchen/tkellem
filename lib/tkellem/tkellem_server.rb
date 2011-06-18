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

  attr_reader :bouncers

  def initialize
    @listeners = {}
    @bouncers = {}

    unless ActiveRecord::Base.connected?
      ActiveRecord::Base.establish_connection({
        :adapter => 'sqlite3',
        :database => File.expand_path("~/.tkellem/tkellem.sqlite3"),
      })
      ActiveRecord::Migrator.migrate(File.expand_path("../migrations", __FILE__), nil)
    end

    ListenAddress.all.each { |a| listen(a) }
    NetworkUser.find_each { |nu| add_bouncer(Bouncer.new(nu)) }
    Observer.forward_to << self
  end

  def stop
    Observer.forward_to.delete(self)
  end

  # callbacks for AR observer events
  def after_create(obj)
    case obj
    when ListenAddress
      listen(obj)
    when NetworkUser
      add_bouncer(Bouncer.new(obj))
    end
  end

  def after_destroy(obj)
    case obj
    when ListenAddress
      stop_listening(obj)
    # TODO: remove bouncer on NetworkUser.destroy
    end
  end

  def listen(listen_address)
    address = listen_address.address
    port = listen_address.port
    ssl = listen_address.ssl

    info "Listening on #{listen_address}"

    @listeners[listen_address.id] = EM.start_server(listen_address.address,
                                                    listen_address.port,
                                                    BouncerConnection,
                                                    self,
                                                    listen_address.ssl)
  end

  def stop_listening(listen_address)
    listener = @listeners[listen_address.id]
    return unless listener
    EM.stop_server(listener)
    info "No longer listening on #{listen_address}"
  end

  def add_bouncer(bouncer)
    key = [bouncer.user.id, bouncer.network.name]
    raise("bouncer already exists: #{key}") if @bouncers.include?(key)
    @bouncers[key] = bouncer
  end

  def find_bouncer(user, network_name)
    key = [user.id, network_name]
    bouncer = @bouncers[key]
    if !bouncer
      # find the public network with this name, and attempt to auto-add this user to it
      network = Network.first(:conditions => { :user_id => nil, :name => network_name })
      if network
        nu = NetworkUser.create!(:user => user, :network => network)
        # AR callback should create the bouncer in sync
        bouncer = @bouncers[key]
      end
    end
    bouncer
  end

  class Observer < ActiveRecord::Observer
    observe 'Tkellem::ListenAddress', 'Tkellem::NetworkUser'
    cattr_accessor :forward_to
    self.forward_to = []

    def after_create(obj)
      forward_to.each { |f| f.after_create(obj) }
    end

    def after_destroy(obj)
      forward_to.each { |f| f.after_destroy(obj) }
    end
  end

  ActiveRecord::Base.observers = Observer
  ActiveRecord::Base.instantiate_observers
end

end
