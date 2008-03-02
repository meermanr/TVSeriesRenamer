#!/usr/bin/python
"""
This is a proof-of-concept script that attempts to determine if it is being run
for the first time based purely on the timestamps contained in the filesystem
against the script's container.

Linux and Windows treat file timestamps differently enough that we must account
for each seperately. In Linux st_ctime is a timestamp for the last change to a
file (either modifying file contents, or file metadata), in Windows it is
"creation time".

Therefore when the file permissions are updated via chmod(), the "last changed"
time is updated in Linux, but no times are updated in Windows. When a file is
modifed by truncate() both "last changed" and "last modified" are updated in
Linux but only "last modified" is updated in Windows.

It follows that our solution is to modify the file (updating "changed" and
"modified x2") and then update its metadata (updating "changed" only). We
modify the file by truncating it to the size it already is (no data loss) and
we update metadata by setting the permissions to what they currenly are (again,
no change).

Tested on Linux, OS X and Windows Vista.

Win32 Notes:
	* If a file is written slowly (i.e. downloaded from the internet) the
	  creation timestamp is when writing started, and last-modified is when the
	  last write occurred. So chances are that we won't be able to detect a
	  first-run on Win32 accurately...

TODO: Detect when the program is read-only and avoid attempting to update the
tmestamps - just assume it is not the first run.
"""

from time	import sleep
from sys	import argv
from os		import stat, chmod

if argv[0] is not '':
	stat_result = stat( argv[0] )
	print "Before:"
	print "  Access: %f" % stat_result.st_atime
	print "  Modify: %f" % stat_result.st_mtime
	print "  Change: %f" % stat_result.st_ctime

	# Accept small differences (in seconds), because some filesystems (notably
	# NTFS and FAT32) do not set ctime == mtime upon file creation, but they
	# are usually pretty close (~1 second)
	if abs( stat_result.st_mtime - stat_result.st_ctime) < 10:
		print "\nTherefore: First run!\n"

		f = file( argv[0], "a" )
		f.seek(0, 2)	# 0 bytes from "end of file" (=2)
		f.truncate()	# To current position: no change
		f.close()

		sleep(1)	# We must sleep to ensure that the timestamp we set above
					# will differ from the one we're about to set

		chmod( argv[0], stat_result.st_mode)	# Update permissions to current permissions: no change

		stat_result = stat( argv[0] )
		print "After:"
		print "  Access: %f" % stat_result.st_atime
		print "  Modify: %f" % stat_result.st_mtime
		print "  Change: %f" % stat_result.st_ctime

	else:
		print "\nTherefore: Not first run.\n"


