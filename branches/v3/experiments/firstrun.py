#!/usr/bin/python
"""
This is a proof-of-concept script that attempts to determine if it is being run
for the first time based purely on the timestamps contained in the filesystem
against the script's container.
"""

import sys, os

if sys.argv[0] is not '':
	stat_result = os.stat( sys.argv[0] )
	print "Before:"
	print "  Access: 0x%x" % stat_result.st_atime
	print "  Modify: 0x%x" % stat_result.st_mtime
	print "  Change: 0x%x" % stat_result.st_ctime

	if stat_result.st_mtime == stat_result.st_ctime:
		print "\nTherefore: First run!\n"
	else:
		print "\nTherefore: Not first run.\n"

	os.chmod( sys.argv[0], stat_result.st_mode )

	stat_result = os.stat( sys.argv[0] )
	print "After:"
	print "  Access: 0x%x" % stat_result.st_atime
	print "  Modify: 0x%x" % stat_result.st_mtime
	print "  Change: 0x%x" % stat_result.st_ctime

