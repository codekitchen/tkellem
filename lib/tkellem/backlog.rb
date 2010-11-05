require 'tkellem/irc_line'

module Tkellem

# Normally there will be one client per backlog, but there can be more than one
# connection for the same backlog, if two or more IRC clients connect with the
# same client name. That situation is equivalent to how most multi-connection
# bouncers like bip work.

class Backlog
  def initialize(name)
    @name = name
    @backlog = []
    @pm_backlogs = Hash.new { |h,k| h[k] = [] }
    @active_conns = []
  end
  attr_reader :name, :backlog, :active_conns, :pm_backlogs

  def handle_message(msg)
    # TODO: only send back response messages like WHO, NAMES, etc. to the
    # BouncerConnection that requested it.
    if !active_conns.empty?
      case msg.command
      when /3\d\d/, /join/i
        # transient response -- we want to forward these, but not backlog
        active_conns.each { |conn| conn.transient_response(msg) }
      when /privmsg/i
        active_conns.each { |conn| conn.send_msg(msg) }
      else
        # do nothing?
      end
    elsif msg.command.match(/privmsg/i)
      if msg.args.first.match(/^#/)
        # room privmsg always goes in a specific backlog
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

end
