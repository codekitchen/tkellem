# encoding: utf-8
require 'eventmachine'
require 'active_record'
require 'rails/observers/activerecord/active_record'

require 'tkellem/bouncer_connection'
require 'tkellem/bouncer'

require 'tkellem/models/backlog_position'
require 'tkellem/models/host'
require 'tkellem/models/listen_address'
require 'tkellem/models/network'
require 'tkellem/models/network_user'
require 'tkellem/models/room'
require 'tkellem/models/setting'
require 'tkellem/models/user'

require 'tkellem/plugins/backlog'
require 'tkellem/plugins/push_service'

module Tkellem

class TkellemServer
  include Tkellem::EasyLogger

  attr_reader :bouncers

  def initialize
    @listeners = {}
    @bouncers = {}
    $tkellem_server = self

    unless ActiveRecord::Base.connected?
      ActiveRecord::Base.establish_connection({
        :adapter => 'sqlite3',
        :database => File.expand_path("~/.tkellem/tkellem.sqlite3"),
      })
      ActiveRecord::Migrator.migrate(File.expand_path("../migrations", __FILE__), nil)
    end

    ListenAddress.all.each { |a| listen(a) }
    NetworkUser.find_each { |nu| add_bouncer(nu) }
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
      add_bouncer(obj)
    end
  end

  def after_destroy(obj)
    case obj
    when ListenAddress
      stop_listening(obj)
    when NetworkUser
      stop_bouncer(obj)
    end
  end

  def listen(listen_address)
    info "Listening on #{listen_address}"
    address = listen_address.address
    # IPv6 literal
    if address[0] == '[' && address[-1] == ']'
      address = address[1..-2]
    end

    @listeners[listen_address.id] = EM.start_server(address,
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

  def add_bouncer(network_user)
    unless network_user.user && network_user.network
      info "Terminating orphan network user #{network_user.inspect}"
      network_user.destroy
      return
    end

    key = bouncers_key(network_user)
    raise("bouncer already exists: #{key}") if @bouncers.include?(key)
    @bouncers[key] = Bouncer.new(network_user)
  end

  def stop_bouncer(network_user)
    key = bouncers_key(network_user)
    bouncer = @bouncers.delete(key)
    if bouncer
      bouncer.kill!
    end
  end

  def find_bouncer(user, network_name)
    key = [user.id, network_name]
    bouncer = @bouncers[key]
    if !bouncer
      # find the public network with this name, and attempt to auto-add this user to it
      network = Network.where(user_id: nil, name: network_name).first
      if network
        NetworkUser.create!(:user => user, :network => network)
        # AR callback should create the bouncer in sync
        bouncer = @bouncers[key]
      end
    end
    bouncer
  end

  def bouncers_key(network_user)
    [network_user.user_id, network_user.network.name]
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
