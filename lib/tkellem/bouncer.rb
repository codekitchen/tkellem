require 'tkellem/irc_line'

class Bouncer
  def initialize(name)
    @name = name
    @backlog = []
    @pm_backlogs = Hash.new { |h,k| h[k] = [] }
    @active_conns = []
  end
  attr_reader :name, :backlog, :active_conns, :pm_backlogs

  def handle_message(msg)
    if !active_conns.empty?
      active_conns.each { |conn| conn.send_msg(msg) }
    else
      if msg.command.match(/privmsg/i) && msg.args.first.match(/^#/)
        # privmsg always goes in a specific backlog
        pm_target = msg.args.first
        bl = pm_backlogs[pm_target]
      else
        # other messages go in the general backlog
        bl = backlog
      end
      bl.push(msg)
    end
  end

  def add_conn(bouncer_conn)
    active_conns << bouncer_conn
  end

  def remove_conn(bouncer_conn)
    active_conns.delete(bouncer_conn)
  end

  def relay(msg)
    active_conns.each { |c| c.send_msg(msg) }
  end

  def send_backlog(conn, pm_target = nil)
    if pm_target
      # send room-specific backlog
      msgs = pm_backlogs.key?(pm_target) ? pm_backlogs[pm_target] : []
    else
      # send the general backlog
      msgs = backlog
    end

    until msgs.empty?
      conn.send_msg(msgs.shift)
    end
  end
end
