require 'spec_helper'
require 'tkellem/irc_message'

include Tkellem

describe IrcMessage, ".parse" do
  it "should parse complex irc lines" do
    orig = ":some_long_prefix COMMAND first second :long arg here"
    line = IrcMessage.parse(orig)
    line.command.should == 'COMMAND'
    line.prefix.should == 'some_long_prefix'
    line.args.size.should == 3
    line.args.should == ['first', 'second', 'long arg here']
    line.replay.should == orig
  end

  it "should parse messages with embedded colons" do
    orig = "MSG #myroom http://google.com/"
    line = IrcMessage.parse(orig)
    line.command.should == "MSG"
    line.args.should == ["#myroom", "http://google.com/"]
    line.replay.should == orig
  end
end

describe IrcMessage, "#with_timestamp" do
  it "should prefix a timestamp to the last arg" do
    line = IrcMessage.parse(":some_long_prefix COMMAND first second :long arg here")
    require 'time'
    timestamp = Time.parse("Thu Nov 29 14:33:20 2001")
    ts_line = line.with_timestamp(timestamp)
    ts_line.should be_a(IrcMessage)
    ts_line.to_s.should == ":some_long_prefix COMMAND first second :14:33:20> long arg here"
  end
end

describe IrcMessage do
  it "should know how to find the last arg" do
    line1 = IrcMessage.parse("TEST one two three")
    line1.args.should == %w(one two three)
    line1.args.last.should == "three"

    line2 = IrcMessage.parse("TEST one two :three")
    line2.args.should == %w(one two three)
    line2.args.last.should == "three"
  end
end

describe IrcMessage, "CTCP" do
  it "should parse basic ACTION messages" do
    msg = IrcMessage.parse(":user1 PRIVMSG #room :\1ACTION is a loser on IRC\1")
    msg.command.should == 'PRIVMSG'
    msg.args.should == ['#room', 'is a loser on IRC']
    msg.ctcp?.should == true
    msg.action?.should == true
    msg.to_s.should == ":user1 PRIVMSG #room :\1ACTION is a loser on IRC\1"
  end
end
