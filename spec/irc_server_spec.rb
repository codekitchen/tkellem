require 'spec_helper'
require 'tkellem/irc_server'

include Tkellem

describe IrcServer, "connection" do
  def make_server
    Class.new do
      include IrcServer

      def send_data(*a); end
    end.new(nil, "spec_server", false, "speccer")
  end

  def send_welcome(s, &just_before_last)
    s.receive_line("001 blah blah")
    s.receive_line("002 more blah")
    s.receive_line("003 even more blah")
    just_before_last && just_before_last.call
    s.receive_line("376 :end of MOTD")
  end

  def connected_server
    s = make_server
    s.post_init
    send_welcome(s)
    s.connected?.should be_true
    s
  end

  it "should connect to the server on creation" do
    s = make_server
    s.connected?.should_not be_true
    s.should_receive(:send_data).with("USER speccer localhost blah :speccer\r\n")
    s.should_receive(:send_data).with("NICK speccer\r\n")
    s.post_init
  end

  it "should join pending rooms once the connection is established" do
    s = make_server
    s.post_init
    s.connected?.should_not be_true # still haven't received the welcome

    s.join_room "#test1"
    # as soon as the end of MOTD is received, the IrcServer will consider itself
    # connected and try to join the rooms.
    s.should_receive(:send_data).with("JOIN #test1\r\n")
    s.should_receive(:send_data).with("JOIN #test2\r\n")

    send_welcome(s) { s.join_room "#test2" }

    s.connected?.should be_true
  end

  it "should pong" do
    s = connected_server
    s.should_receive(:send_data).with("PONG speccer!tkellem :HAI\r\n")
    s.receive_line(":speccer!test@host ping :HAI")
  end
end
