require 'spec_helper'
require 'tkellem/irc_server'

include Tkellem

describe Bouncer, "connection" do
  def make_server
    EM.stub!(:add_timer).and_return(nil)
    b = Bouncer.new(NetworkUser.new(:user => User.new(:username => 'speccer'), :network => Network.new))
    b
  end

  def send_welcome(s, &just_before_last)
    s.should_receive(:send_msg).with("USER speccer localhost blah :speccer")
    s.should_receive(:send_msg).with("NICK speccer")
    s.should_receive(:send_msg).with("AWAY :Away")
    s.connection_established
    s.server_msg(IrcMessage.parse("001 blah blah"))
    s.server_msg(IrcMessage.parse("002 more blah"))
    s.server_msg(IrcMessage.parse("003 even more blah"))
    just_before_last && just_before_last.call
    s.server_msg(IrcMessage.parse("376 :end of MOTD"))
  end

  def connected_server
    s = make_server
    send_welcome(s)
    s.connected?.should be_true
    s
  end

  it "should connect to the server on creation" do
    s = make_server
    s.connected?.should_not be_true
    s.should_receive(:send_msg).with("USER speccer localhost blah :speccer")
    s.should_receive(:send_msg).with("NICK speccer")
    s.should_receive(:send_msg).with("AWAY :Away")
    s.connection_established
  end

  it "should pong" do
    s = connected_server
    s.should_receive(:send_msg).with("PONG tkellem!tkellem :HAI")
    s.server_msg(IrcMessage.parse(":speccer!test@host ping :HAI"))
  end
end
