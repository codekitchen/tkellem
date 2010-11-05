begin
  require 'rubygems'
rescue LoadError
end

pathname = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push(pathname) unless $LOAD_PATH.include?(pathname)

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

    def trace(msg)
      puts("TRACE: #{log_name}: #{msg}") if EasyLogger.trace
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

require 'tkellem/bouncer'
