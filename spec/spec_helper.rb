$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'tkellem'
require 'rspec'

Tkellem::EasyLogger.logger = Logger.new("test.log")
ActiveRecord::Base.logger = Tkellem::EasyLogger.logger

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.migrate(File.expand_path("../../lib/tkellem/migrations", __FILE__), nil)

RSpec.configure do |config|
  config.before(:each) do
    ActiveRecord::Base.connection.increment_open_transactions
    ActiveRecord::Base.connection.begin_db_transaction
  end

  config.after(:each) do
    ActiveRecord::Base.connection.rollback_db_transaction
    ActiveRecord::Base.connection.decrement_open_transactions
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
