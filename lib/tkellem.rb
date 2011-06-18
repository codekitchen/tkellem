module Tkellem
  module EasyLogger
    require 'logger'

    def self.logger=(new_logger)
      @logger = new_logger
      if @logger.is_a?(Logger)
        @logger.formatter = proc do |severity, time, progname, msg|
          obj, msg = msg if msg.is_a?(Array)
          "#{time.strftime('%y-%m-%dT%H:%M:%S')} #{severity[0,3]} #{(obj && obj.log_name) || 'tkellem'} (#{obj && obj.object_id}): #{msg}\n"
        end
      end
    end
    def self.logger
      return @logger if @logger
      self.logger = Logger.new(STDERR)
      @logger
    end

    def self.trace=(val)
      @trace = val
    end
    def self.trace
      @trace || @trace = false
    end

    def log_name
      nil
    end

    def trace(msg)
      puts("TRACE: #{log_name}: #{msg}") if EasyLogger.trace
    end

    def failsafe(event)
      yield
    rescue => e
      # if the failsafe rescue fails, we're in a really bad state and should probably just die
      self.error "exception while handling #{event}"
      self.error e.to_s
      (e.backtrace || []).each { |line| self.error line }
    end

    ::Logger::Severity.constants.each do |level|
      next if level == "UNKNOWN"
      module_eval(<<-EVAL, __FILE__, __LINE__)
      def #{level.downcase}(msg, &block)
        if block
          EasyLogger.logger.#{level.downcase} { [self, block.call] }
        else
          EasyLogger.logger.#{level.downcase}([self, msg])
        end
      end
      EVAL
    end
  end
end

require "tkellem/version"
require 'tkellem/tkellem_server'
