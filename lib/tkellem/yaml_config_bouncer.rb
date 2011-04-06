# supporting class used by bin/tkellem, and can also be used for other apps
# that embed tkellem and want to use the yaml config file format.
# supports reloading the config, with intelligent diffing.

module Tkellem

class YamlConfigBouncer
  attr_reader :config

  def initialize(config)
    @config = config.clone.freeze
    initialize_bouncer
    set_global_options
    create_bouncers
  end

  def reload(new_config)
    old_config = @config
    @config = new_config.clone.freeze
    set_global_options(old_config)
    create_bouncers(old_config)
  end

  protected

  def initialize_bouncer
    @bouncer = Bouncer.new

    @bouncer.on_authenticate do |username, password, irc_server|
      user_config = config['users'][username]
      if user_config && password_sha1 = user_config['password_sha1']
        require 'openssl'
        password_sha1 == OpenSSL::Digest::SHA1.hexdigest(password)
      else
        true
      end
    end
  end

  def set_global_options(old_config = self.config)
    listen = config['listen'] || '0.0.0.0'
    port = config['port'] || 10001
    ssl = config['ssl']

    if old_config['listen'] != listen || old_config['port'] != port || old_config['ssl'] != ssl
      @bouncer.stop_listening(old_config['listen'], old_config['port'])
    end

    @bouncer.listen(listen, port, ssl)

    @bouncer.max_backlog = config['max_backlog'].to_i
  end

  def create_bouncers(old_config = self.config)
    changed_users = old_config['users'].keys.find_all { |u|
      old_config['users'][u] != config['users'][u]
    }
    changed_networks = old_config['networks'].keys.find_all { |n|
      old_config['networks'][n] != config['networks'][n]
    }

    config['bouncers'].each do |bc|
      network = config['networks'][bc['network']]
      user = config['users'][bc['user']]
      next unless user && network
      EasyLogger.logger.info("adding new connection #{bc['network']} for #{bc['user']}")

      server = @bouncer.add_irc_server(bc['network'],
                                       network['host'], network['port'],
                                       network['ssl'],
                                       bc['nick'] || bc['user'])
      (bc['rooms'] || []).each { |room| server.join_room(room['name']) }
      user['clients'].each { |client| server.add_client(client['name']) }
    end

    # TODO: finish up this diffing
  end
end

end
