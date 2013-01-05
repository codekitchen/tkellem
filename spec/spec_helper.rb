$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'tkellem'
require 'rspec'

Tkellem::EasyLogger.logger = Logger.new("test.log")

TestDB = Tkellem::TkellemServer.initialize_database(':memory:')

RSpec.configure do |config|
  config.around(:each) do |block|
    TestDB.transaction(:rollback => :always) do
      block.run()
    end
  end

  def m(line)
    IrcMessage.parse(line)
  end
end
