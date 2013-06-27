$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'mocha/api'

unless ENV['NO_SIMPLECOV']
  require 'simplecov'
  require 'coveralls'
  SimpleCov.formatter = if ENV['TRAVIS']
    Coveralls::SimpleCov::Formatter
  else
    SimpleCov::Formatter::HTMLFormatter
  end
  SimpleCov.start do
    add_filter "/spec"
  end
end

require 'tkellem'

Tkellem::EasyLogger.logger = Logger.new("test.log")
ActiveRecord::Base.logger = Tkellem::EasyLogger.logger

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.migrate(File.expand_path("../../lib/tkellem/migrations", __FILE__), nil)

RSpec.configure do |config|
  config.around(:each) do |test|
    EM.run do
      ActiveRecord::Base.transaction do
        test.run
        raise ActiveRecord::Rollback
      end
      EM.stop
    end
  end

  def m(line)
    IrcMessage.parse(line)
  end

  def em(mod)
    c = Class.new
    c.send(:include, mod)
    c
  end
end
