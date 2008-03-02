#!/usr/bin/python
# vim: set fileencoding=UTF-8:	(Note: this line also used by Python interpreter)
"""
A proof-of-concept script for managing preferences.

Aims:
	* Default values stored seperately from active preferences
	* Active preferences can be stored and retrieved from file by storing the differences from default
"""

import os.path, logging, pickle, sys

logging.basicConfig(level=logging.DEBUG)
logging.info("Script starting")

default_preferences = {
	"interface":	"CLI",
	"scheme":		"$x€€",
	"language":		"en",
}

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
	default_preferences = dict()
	logging = logging.getLogger()

	def __init__(self, defaults, profile=""):
		"""Loads preferences from optional profile name (if found), overriding
		defaults (a dictionary which is treated as read-only)"""

		# Configure logging scope
		self.logging = logging.getLogger(self.__class__.__name__)

		# Copy default settings
		self.default_preferences = defaults

		# Construct default filename
		programname = os.path.basename( sys.argv[0] )
		programname = os.path.splitext( programname )[0]

		homedir = os.path.expanduser("~")

		profile = profile if profile is "" else ".%s" % profile

		filename = ".%src%s" % (programname, profile)
		self.filename = os.path.join(homedir, filename)

		# Attempt to load from default file
		self.load()

	def __setitem__(self, key, value):
		"""x.__setitem__(i, y) <==> x[i]=y
		
		Creates a user-preference, overriding the default"""

		try:
			self.default_preferences[key]	# Check key exists in defaults
			self.user_preferences[key] = value
		except KeyError:
			self.logging.error("Attempted to set a user-preference for which "
					"there is no corresponding default value")
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
			return self.default_preferences[key]

	def save(self, filename=None):
		"""Saves user-preferences to disk.
		
		When 'filename' is not given the default is used, as described in this
		class's main blurb"""

		filename = self.filename if (filename is None) else filename
		self.logging.info( "Saving preferences to %s" % filename )
		
		f = open(filename, "w")
		f.writelines("# This file contains pickled Python data-structures and is not intended to be manually edited\n")
		pickle.dump(self.user_preferences, f)
		f.close()

	def load(self, filename=None):
		"""Loads user-preferences from disk.
		
		When 'filename' is not given the default is used, as described in this
		class's main blurb"""

		filename = self.filename if (filename is None) else filename
		self.logging.info( "Loading preferences from %s" % filename )

		try:
			f = open(self.filename, "rU")

			try:
				f.readline()	# Skip over comment header
				self.user_preferences = pickle.load(f)
			except EOFError, inst:
				self.logging.warning( "Error loading preferences from %s" % self.filename )
				raise Exception

			f.close()

		except (IOError, Exception), inst:
			# Pass exception upwards if we can't handle it
			if type(inst) is IOError:
				if inst.errno != 2:	# "File or Directory not found"
					raise
				else:
					self.logging.debug( "File does not exist: %s" % self.filename )

			self.logging.info( "Preferences could not be loaded" )


pref = Preferences();
print "Just loaded:"
print "  active interface: ", pref["interface"]
print "  active scheme: ", pref["scheme"]
print "  active language: ", pref["language"]

pref["scheme"] = "S$$ E€€"
print "Updated scheme:"
print "  active interface: ", pref["interface"]
print "  active scheme: ", pref["scheme"]
print "  active language: ", pref["language"]

del pref["interface"]
print "Deleted interface:"
print "  active interface: ", pref["interface"]
print "  active scheme: ", pref["scheme"]
print "  active language: ", pref["language"]

pref.save()
