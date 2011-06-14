require 'shellwords'
require 'yaml'

module Tkellem

class TkellemBot
  # careful here -- if no user is given, it's assumed the command is running as
  # an admin
  def self.run_command(line, user, &block)
    args = Shellwords.shellwords(line.downcase)
    command_name = args.shift.upcase
    command = commands[command_name]

    unless command
      yield "Invalid command. Use help for a command listing."
      return
    end

    command.run(args, user, block)
  end

  class Command
    attr_accessor :args

    def self.options
      unless defined?(@options)
        @options = OptionParser.new
        class << @options
          attr_accessor :cmd
          def set(name, *args)
            self.on(*args) { |v| cmd.args[name] = v }
          end
        end
      end
      @options
    end

    def options
      self.class.options
    end

    def self.register(cmd_name)
      cattr_accessor :name
      self.name = cmd_name
      TkellemBot.commands[name.upcase] = self
      self.options.banner = resources(name)['banner'] if resources(name)['banner']
      self.options.separator(resources(name)['help']) if resources(name)['help']
    end

    def self.resources(name)
      @resources ||= YAML.load_file(File.expand_path("../../../resources/bot_command_descriptions.yml", __FILE__))
      @resources[name.upcase] || {}
    end

    class ArgumentError < RuntimeError; end

    def self.admin_only?
      false
    end

    def self.run(args_arr, user, block)
      if admin_only? && !admin_user?(user)
        block.call "You can only run #{name} as an admin."
        return
      end
      cmd = self.new(block)
      options.cmd = cmd
      options.parse!(args_arr)
      cmd.args[:rest] = args_arr
      cmd.execute(cmd.args, user)
    rescue ArgumentError => e
      cmd.respond e.to_s
      cmd.show_help
    end

    def initialize(responder)
      @responder = responder
      @args = {}
    end

    def show_help
      respond(options.to_s)
    end

    def respond(text)
      text.each_line { |l| @responder.call(l.chomp) }
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

    def execute(args, user)
      name = args[:rest].first
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
      elsif (command = TkellemBot.commands[name.upcase])
        r "Help for #{command.name}:"
        r ""
        r command.options.to_s
      else
        r "No help available for #{args.first.upcase}."
      end
      r "**** end of help ****"
    end
  end

  class CRUDCommand < Command
    def self.register_crud(name, model)
      register(name)
      cattr_accessor :model
      self.model = model
      options.set('add', '--add', '-a', "Add a #{model.name}")
      options.set('remove', '--remove', '-r', "Remove a #{model.name}")
      options.set('list', '--list', '-l', "List the current #{model.name.pluralize}")
    end

    def show(m)
      m.to_s
    end

    def find_attributes(args, user)
      attributes(args, user)
    end

    def list(args, user)
      r "All #{self.class.name.pluralize}:"
      model.all.each { |m| r "    #{show(m)}" }
    end

    def remove(args, user)
      instance = model.first(:conditions => find_attributes(args, user))
      if instance
        instance.destroy
        respond "Removed #{show(instance)}"
      else
        respond "Not found"
      end
    end

    def add(args, user)
      instance = model.create(attributes(args, user))
      if instance.errors.any?
        respond "Errors creating:"
        instance.errors.full_messages.each { |m| respond "    #{m}" }
      else
        respond "#{show(instance)} added"
      end
    end

    def execute(args, user)
      if args['list']
        list(args, user)
      elsif args['remove']
        remove(args, user)
      elsif args['add']
        add(args, user)
      else
        raise Command::ArgumentError, "Unknown sub-command"
      end
    end
  end

  class ListenCommand < CRUDCommand
    register_crud 'listen', ListenAddress

    def self.admin_only?
      true
    end

    def self.get_uri(args)
      require 'uri'
      uri = URI.parse(args[:rest].first)
      unless %w(irc ircs).include?(uri.scheme)
        raise Command::ArgumentError, "Invalid URI scheme: #{uri}"
      end
      uri
    rescue URI::InvalidURIError
      raise Command::ArgumentError, "Invalid new address: #{args[:rest].first}"
    end

    def attributes(args, user)
      uri = self.class.get_uri(args)
      { :address => uri.host, :port => uri.port, :ssl => (uri.scheme == 'ircs') }
    end
  end

  class UserCommand < CRUDCommand
    register_crud 'user', User

    def self.admin_only?
      true
    end

    options.set('user', '--user', '-u', 'Set new user as user (the default)')
    options.set('admin', '--admin', 'Set new user as admin')

    def show(user)
      "#{user.username}:#{user.role}"
    end

    def find_attributes(args, user)
      { :username => args[:rest].first }
    end

    def attributes(args, user)
      find_attributes(args).merge({ :role => (args['admin'] ? 'admin' : 'user') })
    end
  end

  class PasswordCommand < Command
    register 'password'

    options.set('username', '--user=username', '-u', 'Change password for other username')

    def execute(args, user)
      if args['username']
        if Command.admin_user?(user)
          user = User.first(:conditions => { :username => args['username'] })
        else
          raise Command::ArgumentError, "Only admins can change other passwords"
        end
      end

      unless user
        raise Command::ArgumentError, "User required"
      end

      password = args[:rest].shift || ''

      if password.size < 4
        raise Command::ArgumentError, "New password too short"
      end

      user.set_password!(password)
      respond "New password set for #{user.username}"
    end
  end

  class NetworkCommand < CRUDCommand
    register_crud 'network', Host

    options.set('public', '--public', 'Set new network as public')
    options.set('username', '--user=username', '-u', 'Create a user-specific network for another user')

    def list(args, user)
      r "All networks:"
      Network.all.each { |m| r "    #{show(m.hosts.first)}" if m.hosts.first }
    end

    def show(host)
      "#{host.network.name}#{' (public)' if host.network.public?} " + host.network.hosts.map { |h| "[#{h}]" }.join(' ')
    end

    def get_network(args, user)
      network_name = args[:rest].shift
      if args['username']
        if Command.admin_user?(user)
          user = User.first(:conditions => { :username => args['username'] })
        else
          raise Command::ArgumentError, "Only admins can change other user's networks"
        end
      end

      network = Network.first(:conditions => { :name => network_name, :user_id => user.id }) if user
      network ||= Network.first(:conditions => { :name => network_name, :user_id => nil })
      if network && network.public? && !self.class.admin_user?(user)
        raise Command::ArgumentError, "Only admins can modify public networks"
      end
      return network_name, network, user
    end

    def remove(args, user)
      network_name, network, user = get_network(args, user)
      if network
        Host.all(:conditions => { :network_id => network.id }).each(&:destroy)
        network.destroy
        respond "Removed #{network.name} #{show(network.hosts.first) if network.hosts.first}"
      else
        respond "Not found"
      end
    end

    def attributes(args, user)
      network_name, network, user = get_network(args, user)

      unless network
        create_public = !user || (user.admin? && args['public'])
        network = Network.create(:name => network_name, :user => (create_public ? nil : user))
        unless create_public
          NetworkUser.create(:user => user, :network => network)
        end
      end

      uri = ListenCommand.get_uri(args)
      { :network => network, :address => uri.host, :port => uri.port, :ssl => (uri.scheme == 'ircs') }
    end
  end
end

end
