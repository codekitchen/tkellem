require 'spec_helper'
require 'tkellem/bouncer_connection'

include Tkellem

describe BouncerConnection, "connect" do
  before do
    @u = User.create(:username => 'speccer')
    @u.password = 'test123'
    @u.save
    @tk = mock(TkellemServer)
    @b = mock(Bouncer)
    @bc = em(BouncerConnection).new(@tk, false)
  end

  it "should ignore blank lines" do
    @bc.should_receive(:error!).never
    @bc.receive_line("")
  end

  it "should connect after receiving credentials" do
    @tk.should_receive(:find_bouncer).with(@u, 'testhost').and_return(@b)
    @bc.receive_line("NICK speccer")
    @bc.receive_line("PASS test123")
    @b.should_receive(:connect_client).with(@bc)
    @bc.receive_line("USER speccer@testhost")
  end

  it "should connect when receiving user before pass" do
    @tk.should_receive(:find_bouncer).with(@u, 'testhost').and_return(@b)
    @bc.receive_line("USER speccer@testhost")
    @bc.receive_line("PASS test123")
    @b.should_receive(:connect_client).with(@bc)
    @bc.receive_line("NICK speccer")
  end

  context "CAP" do
    before do
      BouncerConnection.stubs(:caps).returns(%w{server-time sasl}.to_set)
    end

    it "should list capabilities" do
      @bc.should_receive(:send_msg).with("CAP * LS :server-time sasl")
      @bc.receive_line("CAP LS")
    end

    it "should enable capabilities" do
      @bc.should_receive(:send_msg).with("CAP * ACK :sasl")
      @bc.receive_line("CAP REQ sasl")
      @bc.should_receive(:send_msg).with("CAP * LIST :sasl")
      @bc.receive_line("CAP LIST")
    end

    it "should nak missing capabilities" do
      @bc.should_receive(:send_msg).with("CAP * NAK :sssl")
      @bc.receive_line("CAP REQ sssl")
    end

    it "should enable multiple capabilities at once" do
      @bc.should_receive(:send_msg).with("CAP * ACK :sasl server-time")
      @bc.receive_line("CAP REQ :sasl server-time")
    end

    it "should nak if any capability is missing" do
      @bc.should_receive(:send_msg).with("CAP * NAK :sssl sasl")
      @bc.receive_line("CAP REQ :sssl sasl")
    end

    it "should clear enabled capabilities" do
      @bc.receive_line("CAP REQ sasl")
      @bc.should_receive(:send_msg).with("CAP * ACK :-sasl")
      @bc.receive_line("CAP CLEAR")
    end

    it "should error at unknown sub-command" do
      @bc.should_receive(:error!)
      @bc.receive_line("CAP AWESOME")
    end
  end

  describe "#send_msg" do
    it "should strip tags from non-capable connections" do
      msg = IrcMessage.new
      msg.command = "PRIVMSG"
      msg.tags[:time] = Time.now.iso8601(3)
      @bc.should_receive(:send_data).with("PRIVMSG\r\n")
      @bc.send_msg(msg)
    end

    it "should not strip tags from capable connections" do
      msg = IrcMessage.new
      msg.command = "PRIVMSG"
      msg.tags[:a] = 'b'
      msg.tags[:c] = nil
      @bc.stubs(:tags).returns(true)
      @bc.should_receive(:send_data).with("@a=b;c PRIVMSG\r\n")
      @bc.send_msg(msg)
    end
  end
end

