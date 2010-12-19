require 'spec_helper'
require 'tkellem/irc_line'

include Tkellem

describe IrcLine, ".parse" do
  it "should parse complex irc lines" do
    orig = ":some_long_prefix COMMAND first second :long arg here"
    line = IrcLine.parse(orig)
    line.command.should == 'COMMAND'
    line.prefix.should == 'some_long_prefix'
    line.args.size.should == 2
    line.args.should == ['first', 'second']
    line.ext_arg.should == 'long arg here'
    line.last.should == line.ext_arg
    line.replay.should == orig
  end
end

describe IrcLine, "#with_timestamp" do
  it "should prefix a timestamp to the last arg" do
    line = IrcLine.parse(":some_long_prefix COMMAND first second :long arg here")
    require 'time'
    timestamp = Time.parse("Thu Nov 29 14:33:20 2001")
    ts_line = line.with_timestamp(timestamp)
    ts_line.should be_a(IrcLine)
    ts_line.to_s.should == ":some_long_prefix COMMAND first second :14:33:20> long arg here"
  end
end

describe IrcLine do
  it "should know how to find the last arg" do
    line1 = IrcLine.parse("TEST one two three")
    line1.ext_arg.should be_nil
    line1.args.should == %w(one two three)
    line1.last.should == "three"

    line2 = IrcLine.parse("TEST one two :three")
    line2.ext_arg.should == "three"
    line2.args.should == %w(one two)
    line2.last.should == "three"
  end
end
