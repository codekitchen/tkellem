require 'active_support/core_ext'
require 'celluloid'
require 'sequel'

require 'tkellem/bouncer'
require 'tkellem/bouncer_connection'
require 'tkellem/celluloid_tools'

require 'tkellem/plugins/backlog'
#require 'tkellem/plugins/push_service'

module Tkellem

class TkellemServer
  include Tkellem::EasyLogger

  attr_reader :bouncers, :options

  def self.initialize_database(path)
    Sequel.extension :migration
    db = Sequel.connect({
      :adapter => 'sqlite',
      :database => path,
    })
    migrations_path = File.expand_path("../migrations", __FILE__)
    Sequel::Migrator.apply(db, migrations_path)

    Sequel::Model.raise_on_save_failure = true
    # Can't load the models until we've connected to the database and migrated
    require 'tkellem/models/host'
    require 'tkellem/models/listen_address'
    require 'tkellem/models/network'
    require 'tkellem/models/network_user'
    require 'tkellem/models/setting'
    require 'tkellem/models/user'

    db
  end

  def initialize(options)
    @options = options
    @listeners = Celluloid::SupervisionGroup.new
    @bouncers = {}
    $tkellem_server = self

    @db = self.class.initialize_database(db_file)
  end

  def run
    start_unix_server
    ListenAddress.all { |a| listen(a) }
    NetworkUser.all { |nu| add_bouncer(Bouncer.new(nu)) }

    begin
      sleep 1 while @listeners.alive?
    rescue Interrupt
    end
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

  def start_unix_server
    # This file relies on the models being loaded
    # TODO: this is gross
    require 'tkellem/socket_server'
    CelluloidTools::UnixListener.start(socket_file) do |socket|
      SocketServer.new(socket)
    end
  end

  def listen(listen_address)
    info "Listening on #{listen_address}"

    if listen_address.ssl
      error "SSL listeners not yet supported"
      return
    end

    CelluloidTools::TCPListener.start(listen_address.address,
                                      listen_address.port) do |socket|
      BouncerConnection.new(self, socket).run!
    end
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
        NetworkUser.create!(:user => user, :network => network)
        # AR callback should create the bouncer in sync
        bouncer = @bouncers[key]
      end
    end
    bouncer
  end

  def socket_file
    File.join(options[:path], 'tkellem.socket')
  end

  def db_file
    File.join(options[:path], 'tkellem.sqlite3')
  end
end

end
