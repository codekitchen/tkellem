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

    context "timestamps" do
      it "should parse legacy timestamps" do
        Time.use_zone("US/Mountain") do
          timestamp, msg = Backlog.parse_line(%{10-07-2013 10:10:36 < test: hello}, '#testroom')
          timestamp.should == Time.zone.parse("10-07-2013 10:10:36")
          msg.prefix.should == 'test'
          msg.command.should == 'PRIVMSG'
          msg.args.should == ['#testroom', 'hello']
        end
      end

      it "should parse utc timestamps" do
        Time.use_zone("US/Mountain") do
          timestamp, msg = Backlog.parse_line(%{2013-07-26T23:06:10Z < test: hello}, '#testroom')
          timestamp.should == Time.parse("2013-07-26T23:06:10Z")
          msg.prefix.should == 'test'
          msg.command.should == 'PRIVMSG'
          msg.args.should == ['#testroom', 'hello']
        end
      end

      it "should parse fractional timestamps" do
        Time.use_zone("US/Mountain") do
          timestamp, msg = Backlog.parse_line(%{2013-07-26T23:06:10.345Z < test: hello}, '#testroom')
          timestamp.should == Time.parse("2013-07-26T23:06:10.345Z")
          msg.prefix.should == 'test'
          msg.command.should == 'PRIVMSG'
          msg.args.should == ['#testroom', 'hello']
        end
      end
    end
  end
end
