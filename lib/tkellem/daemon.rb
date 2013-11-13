# encoding: utf-8
require 'fileutils'
require 'optparse'

require 'tkellem'
require 'tkellem/socket_server'

class Tkellem::Daemon
  attr_reader :options

  def initialize(args)
    @args = args
    @options = {
      :path => File.expand_path("~/.tkellem/"),
    }
  end

  def run
    op = OptionParser.new do |opts|
      opts.banner = "Usage #{$0} <command> <options>"
      opts.separator %{\nWhere <command> is one of:
  start      start the jobs daemon
  stop       stop the jobs daemon
  run        start and run in the foreground
  restart    stop and then start the jobs daemon
  status     show daemon status
  admin      run admin commands as if connected to the tkellem console
}

      opts.separator "\n<options>"
      opts.on("-p", "--path", "Use alternate folder for tkellem data (default #{options[:path]})") { |p| options[:path] = p }
      opts.on("--trace", "Enable trace logging") { Tkellem::EasyLogger.trace = true }
      opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
    end
    unless @args.first == 'admin'
      op.parse!(@args)
    end

    FileUtils.mkdir_p(path)
    File.chmod(0700, path)
    command = @args.shift
    case command
    when 'start'
      abort_if_running
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
      daemonize
      start
    when 'admin'
      admin
    when nil
      puts op
    else
      raise("Unknown command: #{command.inspect}")
    end
  end

  protected

  def admin
    require 'socket'
    socket = UNIXSocket.new(socket_file)
    line = @args.join(' ').strip
    if line.empty?
      require 'readline'
      while line = Readline.readline('> ', true)
        admin_command(line, socket)
      end
    else
      admin_command(line, socket)
    end
  end

  def admin_command(line, socket)
    socket.puts(line)
    loop do
     line = socket.readline("\n").chomp
     puts line
     if line == "\0"
       break
     end
    end
  end

  def start
    trap("INT") { EM.stop }
    EM.run do
      @admin = EM.start_unix_domain_server(socket_file, Tkellem::SocketServer)
      Tkellem::TkellemServer.new
    end
  ensure
    remove_files
  end

  def daemonize
    puts "Daemonizing..."
    exit if fork
    Process.setsid
    exit if fork
    @daemon = true
    remove_files
    File.open(pid_file, 'wb') { |f| f.write(Process.pid.to_s) }

    STDIN.reopen("/dev/null")
    STDOUT.reopen(log_file, 'a')
    STDERR.reopen(STDOUT)
    STDOUT.sync = STDERR.sync = true
  end

  def stop
    pid = File.read(pid_file) if File.file?(pid_file)
    if pid.to_i > 0
      puts "Stopping tkellem #{pid}"
      Process.kill('INT', pid.to_i)
      while status(false)
        print "."
        sleep(0.5)
      end
      puts
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

  def abort_if_running
    pid = File.read(pid_file) if File.file?(pid_file)
    if pid.to_i > 0
      puts "tkellem already running, pid: #{pid}"
      exit
    end
  end

  def remove_files
    FileUtils.rm(socket_file) if File.file?(socket_file)
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

  def socket_file
    File.join(path, 'tkellem.socket')
  end

  def log_file
    File.join(path, 'tkellem.log')
  end

end
