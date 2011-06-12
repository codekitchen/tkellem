require 'fileutils'
require 'optparse'

require 'tkellem'

class Tkellem::Daemon
  attr_reader :options

  def initialize(args)
    @args = args
    @options = {
      :path => File.expand_path("~/.tkellem/"),
    }
  end

  def run
    OptionParser.new do |opts|
      opts.banner = "Usage #{$0} <command> <options>"
      opts.separator %{\nWhere <command> is one of:
  start      start the jobs daemon
  stop       stop the jobs daemon
  run        start and run in the foreground
  restart    stop and then start the jobs daemon
  status     show daemon status
}

      opts.separator "\n<options>"
      opts.on("-p", "--path", "Use alternate folder for tkellem data (default #{options[:path]})") { |p| options[:path] = p }
      opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
    end.parse!(@args)

    FileUtils.mkdir_p(path)
    command = @args.shift
    case command
    when 'start'
      daemonize
      start
    when 'stop'
      stop
    when 'run'
      start
    when 'status'
      exit(status ? 0 : 1)
    when 'restart'
      stop if status(false)
      while status(false)
        print "."
        sleep(0.5)
      end
      daemonize
      start
    else
      raise("Unknown command: #{command.inspect}")
    end
  end

  protected

  def start
    trap("INT") { EM.stop }
    EM.run { Tkellem::TkellemServer.new }
  ensure
    remove_pid_file
  end

  def daemonize
    puts "Daemonizing..."
    exit if fork
    Process.setsid
    exit if fork
    @daemon = true
    File.open(pid_file, 'wb') { |f| f.write(Process.pid.to_s) }

    # TODO: set up logging
    STDIN.reopen("/dev/null")
    STDOUT.reopen("/dev/null")
    STDERR.reopen(STDOUT)
    # STDOUT.sync = STDERR.sync = true
  end

  def stop
    pid = File.read(pid_file) if File.file?(pid_file)
    if pid.to_i > 0
      puts "Stopping tkellem #{pid}..."
      Process.kill('INT', pid.to_i)
    else
      status
    end
  end

  def status(print = true)
    pid = File.read(pid_file) if File.file?(pid_file)
    if pid
      puts "tkellem running, pid: #{pid}" if print
    else
      puts "tkellem not running" if print
    end
    pid.to_i > 0 ? pid.to_i : nil
  end

  def remove_pid_file
    return unless @daemon
    pid = File.read(pid_file) if File.file?(pid_file)
    if pid.to_i == Process.pid
      FileUtils.rm(pid_file)
    end
  end

  def path
    options[:path]
  end

  def pid_file
    File.join(path, 'tkellem.pid')
  end

end
