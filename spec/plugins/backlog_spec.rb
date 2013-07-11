require 'spec_helper'
require 'tkellem/irc_message'
require 'time'

include Tkellem

describe Backlog do
  describe '.parse_line' do
    it "should parse other user names" do
      def cmp(username, message = "test 1 2")
        timestamp, msg = Backlog.parse_line(%{10-07-2013 10:10:36 < #{username}: #{message}}, '#testroom')
        expected = IrcMessage.new(username, 'PRIVMSG', ['#testroom', message])
        msg.should == expected
      end

      cmp("dude")
      cmp("dude@some/fancy/web/addr.blah")
      cmp("dude!~dude@12:34:56")
      cmp("dude!~dude@12:34:56", "hey dude: test")
    end
  end
end
