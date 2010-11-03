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
      if msg.command.match(/privmsg/i)
        # privmsg always goes in a specific backlog
        pm_target = msg.args.first
        pm_backlogs[pm_target].push msg
      else
        # other messages go in the general backlog
        backlog.push msg
      end
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

  def send_backlog(conn, pm_target)
    msgs = pm_backlogs.key?(pm_target) ? pm_backlogs[pm_target] : []
    until msgs.empty?
      conn.send_msg(msgs.shift)
    end
  end
end
