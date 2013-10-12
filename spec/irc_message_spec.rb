require 'spec_helper'
require 'tkellem/irc_message'
require 'time'

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

  it "should parse and replay messages with leading colons" do
    orig = "MSG #myroom ::)"
    line = IrcMessage.parse(orig)
    line.command.should == "MSG"
    line.args.should == ["#myroom", ":)"]
    line.replay.should == orig
  end

  it "should parse with no arguments" do
    line = IrcMessage.parse("AWAY")
    line.command.should == "AWAY"
    line.args.should == []
    line.replay.should == "AWAY"
  end
end

describe IrcMessage, "#with_timestamp" do
  it "should prefix a timestamp to the last arg" do
    line = IrcMessage.parse(":some_long_prefix COMMAND first second :long arg here")
    timestamp = Time.parse("2001-11-29T19:33:20")
    ts_line = line.with_timestamp(timestamp)
    ts_line.should be_a(IrcMessage)
    ts_line.to_s.should == ":some_long_prefix COMMAND first second :2001-11-29 19:33:20> long arg here"
  end

  it "should not prefix the date if the message is < 24 hours old" do
    line = IrcMessage.parse(":some_long_prefix COMMAND first second :long arg here")
    timestamp = 3.hours.ago
    ts_line = line.with_timestamp(timestamp)
    ts_line.should be_a(IrcMessage)
    ts_line.to_s.should == ":some_long_prefix COMMAND first second :#{timestamp.strftime("%H:%M:%S")}> long arg here"
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

  describe ".parse_client_command" do
    it "should return nil for non-client commands" do
      IrcMessage.parse_client_command("PRIVMSG a :b c d").should == nil
    end

    it "should turn /msg into a PRIVMSG command" do
      IrcMessage.parse_client_command("/msg brian hai there").should ==
        IrcMessage.new(nil, "PRIVMSG", ["brian", "hai there"])
    end

    it "should treat other commands literally" do
      IrcMessage.parse_client_command("/join #tkellem").should ==
        IrcMessage.new(nil, "JOIN", ["#tkellem"])
    end
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
