#!/usr/bin/python
# vim: set fileencoding=UTF-8:	(Note: this line also used by Python interpreter)
"""
A proof-of-concept script for managing preferences.

Aims:
	* Default values stored seperately from active preferences
	* Active preferences can be stored and retrieved from file by storing the differences from default
"""

import os.path, logging, pickle, sys

#logging.basicConfig(level=logging.DEBUG)
logging.info("Script starting")

default_preferences = dict()
default_preferences["interface"] = "CLI"
default_preferences["scheme"] = "$x€€"
default_preferences["language"] = "en"

class Preferences():
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

	filename = None
	user_preferences = dict()

	def __init__(self, profile=""):
		"""Loads preferences from optional profile name (if it exists), or loads defaults"""

		profile = profile if profile is "" else ".%s" % profile
		programname = sys.argv[0]
		print programname
		homedir = os.path.expanduser("~")
		filename = ".tvrenamerrc%s" % profile
		self.filename = os.path.join(homedir, filename)

		try:
			f = open(self.filename, "rU")
			logging.debug( "Preferences file %s exists" % self.filename )

			try:
				self.user_preferences = pickle.load(f)
			except EOFError, inst:
				logging.warning( "Error loading preferences from %s" % self.filename )
				raise Exception

			f.close()

		except (IOError, Exception), inst:
			# Pass exception upwards if we can't handle it
			if type(inst) is IOError:
				if inst.errno != 2:	# "File or Directory not found"
					raise
				else:
					logging.debug( "Prefrences file %s does not exist." % self.filename )

			logging.info( "No preferences loaded" )

	def __setitem__(self, key, value):
		"""x.__setitem__(i, y) <==> x[i]=y
		
		Creates a user-preference, overriding the default"""
		try:
			default_preferences[key]	# Check key exists in defaults
			self.user_preferences[key] = value
		except KeyError:
			logging.warning("Attempted to set a user-preferences for which there is not corresponding default value")
			raise

	def __delitem__(self, key):
		"""x.__delitem__(y) <==> del x[y]
		
		Removes a user-preferences, restoring the default"""
		try:
			del self.user_preferences[key]
		except KeyError:
			pass

	def __getitem__(self, key):
		"""x.__getitem__(y) <==> x[y]
		
		Retrieves a user-preferences if it exists, default otherwise"""
		try:
			return self.user_preferences[key]
		except KeyError:
			return default_preferences[key]

default = Preferences();
print "Just loaded:"
print "  active interface: ", default["interface"]
print "  active scheme: ", default["scheme"]
print "  active language: ", default["language"]

default["scheme"] = "S$$ E€€"
print "Updated scheme:"
print "  active interface: ", default["interface"]
print "  active scheme: ", default["scheme"]
print "  active language: ", default["language"]

del default["interface"]
print "Deleted interface:"
print "  active interface: ", default["interface"]
print "  active scheme: ", default["scheme"]
print "  active language: ", default["language"]
