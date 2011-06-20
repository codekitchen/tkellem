require 'spec_helper'
require 'tkellem/bouncer_connection'

include Tkellem

describe BouncerConnection, "connect" do
  before do
    u = User.create(:username => 'speccer')
    u.password = 'test123'
    u.save
    tk = mock(TkellemServer)
    @b = mock(Bouncer)
    tk.should_receive(:find_bouncer).with(u, 'testhost').and_return(@b)
    @bc = em(BouncerConnection).new(tk, false)
  end

  it "should connect after receiving credentials" do
    @bc.receive_line("NICK speccer")
    @bc.receive_line("PASS test123")
    @b.should_receive(:connect_client).with(@bc)
    @bc.receive_line("USER speccer@testhost")
  end

  it "should connect when receiving user before pass" do
    @bc.receive_line("USER speccer@testhost")
    @bc.receive_line("PASS test123")
    @b.should_receive(:connect_client).with(@bc)
    @bc.receive_line("NICK speccer")
  end
end

