#
# Regular cron jobs for the libfprint package.
#
0 4	* * *	root	[ -x /usr/bin/libfprint_maintenance ] && /usr/bin/libfprint_maintenance
