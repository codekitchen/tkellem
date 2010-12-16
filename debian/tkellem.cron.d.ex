#
# Regular cron jobs for the tkellem package
#
0 4	* * *	root	[ -x /usr/bin/tkellem_maintenance ] && /usr/bin/tkellem_maintenance
