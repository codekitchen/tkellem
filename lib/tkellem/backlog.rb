require 'tkellem/irc_message'

module Tkellem

# Normally there will be one client per backlog, but there can be more than one
# connection for the same backlog, if two or more IRC clients connect with the
# same client name. That situation is equivalent to how most multi-connection
# bouncers like bip work.

class Backlog

  class BacklogLine < Struct.new(:irc_message, :time)
  end

  def initialize
    @backlog = []
    @pm_backlogs = Hash.new { |h,k| h[k] = [] }
    @active_conns = []
  end
  attr_reader :backlog, :active_conns, :pm_backlogs

  def handle_message(msg)
    # TODO: only send back response messages like WHO, NAMES, etc. to the
    # BouncerConnection that requested it.
    # if !active_conns.empty?
    #   case msg.command
    #   when /3\d\d/, /join/i, /part/i
    #     # transient response -- we want to forward these, but not backlog
    #     active_conns.each { |conn| conn.transient_response(msg) }
    #   else
    #     active_conns.each { |conn| conn.send_msg(msg) }
    #   end
    # elsif
    if msg.command.match(/privmsg/i)
      if msg.args.first.match(/^#/)
        # room privmsg always goes in a specific backlog
        pm_target = msg.args.first
        bl = pm_backlogs[pm_target]
      else
        # other messages go in the general backlog
        bl = backlog
      end
      bl.push(BacklogLine.new(msg, Time.now))
      # limit_backlog(bl)
    end
  end

  # def limit_backlog(bl)
  #   bl.shift until !max_backlog || bl.size <= max_backlog
  # end

  # def max_backlog=(new_val)
  #   @max_backlog = new_val
  #   limit_backlog(backlog)
  #   pm_backlogs.each { |k,bl| limit_backlog(bl) }
  # end

  def add_client(client, device_name)
    active_conns << client
  end

  def remove_client(client)
    active_conns.delete(client)
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
      backlog_line = msgs.shift
      conn.send_msg(backlog_line.irc_message.with_timestamp(backlog_line.time))
    end
  end
end

end
