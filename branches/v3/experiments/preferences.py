#!/usr/bin/python
"""
A proof-of-concept script for managing preferences.

Aims:
	* Default values stored seperately from active preferences
	* Active preferences can be stored and retrieved from file by storing the differences from default
"""

import os.path

class Preferences:
	"""
	A system for non-voltatile storage and retrieval of Python structures.

	Intended to be used for managing user preferences via named profiles, with
	the default profile name being an empty string.

	Preference files are stored in the user's home directory, and are named
	after the current script + "rc" + optional profile name. For instance, if a
	script is called testscript.py, the default profile will be
	stored/retrieved from ~/.testscriptrc, and a profile named "alternative"
	would be at ~/.testscriptrc.alternative
	"""
	def __init__(self, name=""):
		"""Loads preferences from optional profile name (if it exists), or loads defaults"""
		name = name if name is "" else ".%s" % name
		filename = "~%s.tvrenamerrc%s" % (os.sep, name)
		filename = os.path.expanduser(filename)
		try:
			f = open(filename, "rU")
			print "Preferences file %s already exists, reading:" % filename
			print f.read()
			f.close()
		except IOError, inst:
			# Error 2 = File or Directory not found
			if inst.errno != 2:
				raise
			print "Prefrences file %s does not exist." % filename

default = Preferences();
default = Preferences("default");
