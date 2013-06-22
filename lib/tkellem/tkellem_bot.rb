require 'shellwords'
require 'yaml'

module Tkellem

class TkellemBot
  # careful here -- if no bouncer is given, it's assumed the command is running as
  # an admin
  def self.run_command(line, bouncer, &block)
    args = Shellwords.shellwords(line)
    command_name = args.shift.upcase
    command = commands[command_name]

    unless command
      yield "Invalid command. Use help for a command listing."
      return
    end

    command.run(args, bouncer, block)
  end

  class Command
    attr_accessor :args, :bouncer, :opts, :options

    def self.option(name, *args)
      @options ||= {}
      @options[name] = args
    end

    def self.admin_option(name, *args)
      option(name, *args)
      @admin_onlies ||= []
      @admin_onlies << name
    end

    def self.register(cmd_name)
      cattr_accessor :name
      self.name = cmd_name
      TkellemBot.commands[name.upcase] = self
    end

    def self.resources(name)
      @resources ||= YAML.load_file(File.expand_path("../../../resources/bot_command_descriptions.yml", __FILE__))
      @resources[name.upcase] || {}
    end

    class ArgumentError < RuntimeError; end

    def self.admin_only?
      true
    end

    def self.build_options(user, cmd = nil)
      OptionParser.new.tap do |options|
        @options.try(:each) { |opt_name,args|
          next if !admin_user?(user) && @admin_onlies.include?(opt_name)
          options.on(*args) { |v| cmd.opts[opt_name] = v }
        }
        resources = self.resources(name)
        options.banner = resources['banner'] if resources['banner']
        options.separator(resources['help']) if resources['help']
      end
    end

    def self.run(args_arr, bouncer, block)
      if admin_only? && !admin_user?(bouncer.try(:user))
        block.call "You can only run #{name} as an admin."
        return
      end
      cmd = self.new(block)

      cmd.args = args_arr
      cmd.bouncer = bouncer

      cmd.options = build_options(bouncer.try(:user), cmd)
      cmd.options.parse!(args_arr)

      cmd.execute
    rescue ArgumentError, OptionParser::InvalidOption => e
      cmd.respond e.to_s
    end

    def initialize(responder)
      @responder = responder
      @opts = {}
    end

    def user
      bouncer.try(:user)
    end

    def show_help
      respond(options)
    end

    def respond(text)
      text.to_s.each_line { |l| @responder.call(l.chomp) }
    end
    alias_method :r, :respond

    def self.admin_user?(user)
      !user || user.admin?
    end
  end

  cattr_accessor :commands
  self.commands = {}

  class Help < Command
    register 'help'

    def self.admin_only?
      false
    end

    def execute
      name = args.shift.try(:upcase)
      r "**** tkellem help ****"
      if name.nil?
        r "For more information on a command, type:"
        r "help <command>"
        r ""
        r "The following commands are available:"
        TkellemBot.commands.keys.sort.each do |name|
          command = TkellemBot.commands[name]
          next if command.admin_only? && user && !user.admin?
          r "#{name}#{' ' * (25-name.length)}"
        end
      elsif (command = TkellemBot.commands[name])
        r "Help for #{command.name}:"
        r ""
        r command.build_options(user)
      else
        r "No help available for #{name}."
      end
      r "**** end of help ****"
    end
  end

  class CRUDCommand < Command
    def self.register_crud(name, model)
      register(name)
      cattr_accessor :model
      self.model = model
      option('remove', '--remove', '-r', "delete the specified record")
    end

    def show(m)
      m.to_s
    end

    def find_attributes
      attributes
    end

    def list
      r "All #{self.class.name.pluralize}:"
      model.all.each { |m| r "    #{show(m)}" }
    end

    def modify
      instance = model.first(:conditions => find_attributes)
      new_record = false
      if instance
        instance.attributes = attributes
        if instance.changed?
          instance.save
        else
          respond "   #{show(instance)}"
          return
        end
      else
        new_record = true
        instance = model.create(attributes)
      end
      if instance.errors.any?
        respond "Error:"
        instance.errors.full_messages.each { |m| respond "    #{m}" }
        respond "    #{show(instance)}"
      else
        respond(new_record ? "created:" : "updated:")
        respond "    #{show(instance)}"
      end
    end

    def remove
      instance = model.first(:conditions => find_attributes)
      if instance
        instance.destroy
        respond "Removed #{show(instance)}"
      else
        respond "Not found"
      end
    end

    def execute
      if opts['remove'] && args.length == 1
        remove
      elsif args.length == 0
        list
      elsif args.length == 1
        modify
      else
        raise Command::ArgumentError, "Unknown sub-command"
      end
    end
  end

  class ListenCommand < CRUDCommand
    register_crud 'listen', ListenAddress

    def self.get_uri(arg)
      require 'uri'
      uri = URI.parse(arg)
      unless %w(irc ircs).include?(uri.scheme)
        raise Command::ArgumentError, "Invalid URI scheme: #{uri}"
      end
      uri
    rescue URI::InvalidURIError
      raise Command::ArgumentError, "Invalid new address: #{arg}"
    end

    def attributes
      uri = self.class.get_uri(args.first)
      { :address => uri.host, :port => uri.port, :ssl => (uri.scheme == 'ircs') }
    end
  end

  class UserCommand < CRUDCommand
    register_crud 'user', User

    option('role', '--role=ROLE', 'Set user role [admin|user]')

    def show(user)
      "#{user.username}:#{user.role}"
    end

    def find_attributes
      { :username => args.first.downcase }
    end

    def attributes
      find_attributes.tap { |attrs|
        role = opts['role'].try(:downcase)
        attrs['role'] = role if %w(user admin).include?(role)
      }
    end
  end

  class PasswordCommand < Command
    register 'password'

    admin_option('username', '--user=username', '-u', 'Change password for other username')

    def self.admin_only?
      false
    end

    def execute
      user = self.user

      if opts['username']
        if Command.admin_user?(user)
          user = User.first(:conditions => { :username => opts['username'] })
        else
          raise Command::ArgumentError, "Only admins can change other passwords"
        end
      end

      unless user
        raise Command::ArgumentError, "User required"
      end

      password = args.shift || ''

      if password.size < 4
        raise Command::ArgumentError, "New password too short"
      end

      user.password = password
      user.save!
      respond "New password set for #{user.username}"
    end
  end

  class AtConnectCommand < Command
    register 'atconnect'

    option('remove', '--remove', '-r', 'Remove previously configured command')
    admin_option('network', '--network=network', '-n', 'Change atconnect for all users on a public network')

    def self.admin_only?
      false
    end

    def list(target)
      target.reload
      if target.is_a?(NetworkUser) && target.network.public?
        r "Network-wide commands are prefixed with [N], user-specific commands with [U]."
        r "Network-wide commands can only be modified by admins."
        list(target.network)
      end
      prefix = target.is_a?(Network) ? 'N' : 'U'
      target.at_connect.try(:each) { |line| r "    [#{prefix}] #{line}" }
    end

    def execute
      if opts['network'].present? # only settable by admins
        target = Network.first(:conditions => ["name = ? AND user_id IS NULL", opts['network'].downcase])
      else
        target = bouncer.try(:network_user)
      end
      raise(Command::ArgumentError, "No network found") unless target

      if args.size == 0
        r "At connect:"
        list(target)
      else
        line = args.join(' ')
        raise(Command::ArgumentError, "atconnect commands must start with a /") unless line[0] == '/'[0]
        if opts['remove']
          target.at_connect = (target.at_connect || []).reject { |l| l == line }
        else
          target.at_connect = (target.at_connect || []) + [line]
        end
        target.save
        r "At connect commands modified:"
        list(target)
      end
    end
  end

  class NetworkCommand < Command
    register 'network'

    def self.admin_only?
      false
    end

    option('remove', '--remove', '-r', "Remove a hostname for a network, or the entire network if no host is given.")
    option('network', '--name=NETWORK', '-n', "Operate on a different network than the current connection.")
    admin_option('public', '--public', "Create new public network. Once created, public/private status can't be modified.")

    def list
      public_networks = Network.all(:conditions => 'user_id IS NULL')
      user_networks = user.try(:reload).try(:networks) || []
      if user_networks.present? && public_networks.present?
        r "Public networks are prefixed with [P], user-specific networks with [U]."
      end
      (public_networks + user_networks).each do |net|
        prefix = net.public? ? 'P' : 'U'
        r "    [#{prefix}] #{show(net)}"
      end
    end

    def show(network)
      "#{network.name} " + network.hosts.map { |h| "[#{h}]" }.join(' ')
    end

    def execute
      # TODO: this got gross
      if args.empty? && !opts['remove']
        list
        return
      end

      if opts['network'].present?
        target = Network.first(:conditions => ["name = ? AND user_id = ?", opts['network'].downcase, user.try(:id)])
        target ||= Network.first(:conditions => ["name = ? AND user_id IS NULL", opts['network'].downcase]) if self.class.admin_user?(user)
      else
        target = bouncer.try(:network)
        if target && target.public? && !self.class.admin_user?(user)
          raise(Command::ArgumentError, "Only admins can modify public networks")
        end
        raise(Command::ArgumentError, "No network found") unless target
      end

      uri = ListenCommand.get_uri(args.shift) unless args.empty?
      addr_args = { :address => uri.host, :port => uri.port, :ssl => (uri.scheme == 'ircs') } if uri

      if opts['remove']
        raise(Command::ArgumentError, "No network found") unless target
        raise(Command::ArgumentError, "You must explicitly specify the network to remove") unless opts['network']
        if uri
          target.hosts.first(:conditions => addr_args).try(:destroy)
          respond "    #{show(target)}"
        else
          target.destroy
          r "Network #{target.name} removed"
        end
      else
        unless target
          create_public = (self.class.admin_user?(user) && opts['public'])
          raise(Command::ArgumentError, "Only public networks can be created without a user") unless create_public || user
          admin_or_user_networks = self.class.admin_user?(user) || Setting.get('allow_user_networks') == 'true'
          raise(Command::ArgumentError, "Creating user networks has been disabled by the admins") unless admin_or_user_networks
          target = Network.create(:name => opts['network'], :user => (create_public ? nil : user))
          unless create_public
            NetworkUser.create(:user => user, :network => target)
          end
        end

        target.attributes = { :hosts_attributes => [addr_args] }
        target.save
        if target.errors.any?
          respond "Error:"
          target.errors.full_messages.each { |m| respond "    #{m}" }
          respond "    #{show(target)}"
        else
          respond("updated:")
          respond "    #{show(target)}"
        end
      end
    end
  end

  class SettingCommand < Command
    register 'setting'

    def self.setting_resources(name)
      @setting_resources ||= YAML.load_file(File.expand_path("../../../resources/setting_descriptions.yml", __FILE__))
      @setting_resources[name] || {}
    end

    def execute
      case args.size
      when 0
        r "Settings:"
        Setting.all.each { |s| r "    #{s}" }
      when 1
        setting = Setting.find_by_name(args.first)
        if setting
          r(setting.to_s)
          desc = self.class.setting_resources(setting.name)
          if desc['help']
            desc['help'].each_line { |l| r l }
          end
        else
          r("No setting with that name")
        end
      when 2
        setting = Setting.set(args[0], args[1])
        setting ? r(setting.to_s) : r("No setting with that name")
      else
        show_help
      end
    end
  end

  class ConnectionsCommand < Command
    register 'connections'

    def execute
      require 'socket'
      $tkellem_server.bouncers.each do |k, bouncer|
        respond "#{bouncer.user.username}@#{bouncer.network.name} (#{bouncer.connected? ? 'connected' : 'connecting'}) #{"since #{bouncer.connected_at}" if bouncer.connected?}"
        bouncer.active_conns.each do |conn|
          port, addr = Socket.unpack_sockaddr_in(conn.get_peername)
          respond "    #{addr} device=#{conn.device_name} since #{conn.connected_at}"
        end
      end
    end
  end
end

end
