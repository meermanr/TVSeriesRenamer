#!/usr/bin/python
# vim: set fileencoding=UTF-8:	(Note: this line also used by Python interpreter)

# Uncomment the following two lines to affect the logging level globally
# (including within Preferences)
#import logging
#logging.basicConfig(level=logging.DEBUG)	# Optional, defaults to warning

class Preferences():
	"""
	Given a base dictionary, this class transparently maintains an overlay
	dictionary. When you attempt to read a value from the dictionary, the value
	in the overlay is returned if present, otherwise the value is base is
	returned. When setting a value only the overlay is updated. Similarly,
	deleting an element only removes it from the overlay, so that a subsequent
	read will give you the value present in base.
	
	This class is intended to be used for layering user preferences to allow
	multiple "profiles" (saved overlays) to be combined. Each instance of this
	class will attempt to read in its overlay from a file on disk, whose name
	is derived from the current script's name and the (optional) profile name
	provided during instance creation.

	Assuming a script called "testscript" and profiles named "first" and
	"second", the following files are used to save/load overlays:

		~/testscriptrc			<-- Loaded with Preferences(base)
		~/testscriptrc.first	<-- Loaded with Preferences(base, "first")
		~/testscriptrc.second	<-- Loaded with Preferences(base, "second")

	For example, consider the following usage:

		base = {
			"pref1" = "base",
			"pref2" = "base",
			"pref3" = "base"
			}
		
		p = Preferences(base)

	At this point, p contains:

		p["pref1"] == "base"
		p["pref2"] == "base"
		p["pref3"] == "base"

	We can set our preferences like so:

		p["pref1"] = "user_choice_1"
		p["pref2"] = "user_choice_2"
	
	Which affects our values like so:

		p["pref1"] == "user_choice_1"
		p["pref2"] == "user_choice_2"
		p["pref3"] == "base"

	If we then delete an element, we effectively restore the base value:

		del( p["pref1"] )

	Which gives us:

		p["pref1"] == "base"
		p["pref2"] == "user_choice_2"
		p["pref3"] == "base"
	
	More advanced usage would involve multiple layers of Preferences(), such as:

		base = {}
		os_pref = Preferences(base, os.name)
		user_pref = Preferences(os_pref, "user")
	
	Where anything defined in os_pref overrides the definition in base, and
	anything defined in user_pref overrides that of os_pref. The power in this
	setup is that you can change something in the middle layer, os_pref, and it
	will only affect users who have not specified their own choice for that
	item.

	"""


	"""
	Do NOT init variables here, because if you do you may get strange
	behaviour...

	Suppose you had

		local_overlay = dict()

	then each instance created from this class will have the name
	"local_overlay" bound to _exactly_ the same object in memory (as can be
	verified with the "is" keyword). This means that when you modify it in any
	instance, all other instances will also be affected. This is almost
	certainly undesirable.
	"""

	filename		= None
	local_overlay	= None
	base_values		= None
	logging			= None

	def __init__(self, defaults, profile=""):
		"""
		Loads preferences from optional profile name (if found), overriding
		defaults (a dictionary which is treated as read-only)
		"""
		import os.path, sys, logging

		# Init instance data
		# Construct the logging scope-name from the class name and active profile
		self.logging = logging.getLogger("%s%s" % (self.__class__.__name__, profile) )
		self.base_values = defaults
		self.local_overlay = dict()

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
		"""
		x.__setitem__(i, y) <==> x[i]=y
		
		Creates a user-preference, overriding the default
		"""

		# Check key exists in defaults
		try:
			self.base_values[key]
		except KeyError:
			self.logging.error("Attempted to set a user-preference for which "
					"there is no corresponding default value")
			raise

		self.logging.debug( "Setting %s" % key )
		self.local_overlay[key] = value

	def __delitem__(self, key):
		"""
		x.__delitem__(y) <==> del x[y]
		
		Removes a user-preference, restoring the default
		"""

		try:
			del self.local_overlay[key]
		except KeyError:
			pass

	def __getitem__(self, key):
		"""
		x.__getitem__(y) <==> x[y]
		
		Retrieves a user-preference if it exists, default otherwise
		"""

		# Lookup the name of the supplied index
		# (Implementing this allows convenient interation over all preferences)
		if type(key) is int:
			key = self.keys()[key]

		try:
			return self.local_overlay[key]
		except KeyError:
			return self.base_values[key]

	def save(self, filename=None):
		"""
		Saves user-preferences to disk.
		
		When 'filename' is not given the default is used, as described in this
		class's main blurb
		"""
		# NB: encodings is a dependancy of pickle that is otherwise uncaught by
		# py2exe and cx_freeze
		import pickle, encodings.string_escape

		filename = self.filename if (filename is None) else filename
		self.logging.info( "Saving preferences to %s" % filename )
		
		f = open(filename, "w")
		f.writelines("# This file contains pickled Python data-structures and "
				"is not intended to be manually edited\n")
		pickle.dump(self.local_overlay, f)
		f.close()

	def load(self, filename=None):
		"""
		Loads user-preferences from disk.
		
		When 'filename' is not given the default is used, as described in this
		class's main blurb
		"""
		# NB: encodings is a dependancy of pickle that is otherwise uncaught by
		# py2exe and cx_freeze
		import pickle, encodings.string_escape

		filename = self.filename if (filename is None) else filename
		self.logging.debug( "Attempting to load preferences from %s" % filename )

		try:
			f = open(self.filename, "rU")

			try:
				f.readline()	# Skip over comment header
				self.local_overlay = pickle.load(f)
			except EOFError, inst:
				self.logging.warning( "Error loading preferences from %s" % self.filename )
				raise Exception

			f.close()
			self.logging.info( "Loaded preferences from %s" % filename )

		except (IOError, Exception), inst:
			# Pass exception upwards if we can't handle it
			if type(inst) is IOError:
				if inst.errno == 2:	# "File or Directory not found"
					self.logging.debug( "File does not exist: %s" % self.filename )
			else:
				self.logging.warning( "Unable to load preferences from %s: (%s) %s" 
						% (self.filename, type(inst).__name__, inst.__str__() ) )


	def keys(self):
		"""
		P.keys() -> list of P's keys
		"""

		return self.base_values.keys()

# TODO: Implement an iterator
#	def __iter__(self):
#		"""
#		x.__iter__() <==> iter(x)
#		"""
#	
#		# Should return an iterator object, which also implement this method
#		# (returning itself), and should also be exposed as iterkeys()


##
# Example use

# Create a dictionary of defaults
default_preferences = {
		"pref0":	"zero ",
		"pref1":	"zero ",
		"pref2":	"zero ",
		"pref3":	"zero ",
		"pref4":	"zero "
}

# Create an instance, using default_preferences as the base dictionary
p1 = Preferences(default_preferences)

# Create more layers by passing an existing Preferences object as the base dictionary
p2 = Preferences(p1, "2")
p3 = Preferences(p2, "3")
p4 = Preferences(p3, "4")

# Modify each layer seperately
p1["pref1"] = "one  "
p1["pref2"] = "one  "
p1["pref3"] = "one  "
p1["pref4"] = "one  "

p2["pref2"] = "two  "
p2["pref3"] = "two  "
p2["pref4"] = "two  "

p3["pref3"] = "three"
p3["pref4"] = "three"

p4["pref4"] = "four "

print "defaults: ", [default_preferences[x] for x in default_preferences]
print "p1      : ", [x for x in p1]
print "p2      : ", [x for x in p2]
print "p3      : ", [x for x in p3]
print "p4      : ", [x for x in p4]

