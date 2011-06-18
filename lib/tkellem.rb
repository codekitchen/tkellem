module Tkellem
  module EasyLogger
    require 'logger'

    def self.logger=(new_logger)
      @logger = new_logger
    end
    def self.logger
      return @logger if @logger
      @logger = Logger.new(STDERR)
      @logger.datetime_format = "%Y-%m-%d"
      @logger
    end

    def self.trace=(val)
      @trace = val
    end
    def self.trace
      @trace || @trace = false
    end

    def log_name
      ""
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
      def #{level.downcase}(msg)
        EasyLogger.logger.#{level.downcase}("\#{log_name} (\#{object_id}): \#{msg}")
      end
      EVAL
    end
  end
end

require "tkellem/version"
require 'tkellem/tkellem_server'
