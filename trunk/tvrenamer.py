#!/usr/bin/python -i 

# RobM's TV Series Renamer

import os, glob, logging
import sys, traceback, inspect

# TODO: Add a preferences system (using the pickle module to store and retrieve
# complex python data structures)
# TODO: Look into using urllib2 (a standard library) for grabbing online data

def prompt(question, default_answer=None):
	"""Gets input from a user, optionally letting them use a default by hitting
	return without entering anything"""

	if( default_answer is None ):
		message = "%s: " % (question)
	else:
		message = "%s [%s]: " % (question, default_answer)

	answer = raw_input(message)

	if answer == "":
		return default_answer
	else:
		return answer

def get_file_list(path):
	filelist = []
	for extension in ['avi', 'mkv', 'ogm', 'mpg', 'mpeg', 'rm', 'wmv', 'mp4', 'mpeg4', 'srt', 'sub', 'ssa', 'smi', 'sami', 'txt']:
		filelist.extend( glob.glob(path + os.sep + "*." + extension) )

	return filelist

class Episode:
	"""Tracks data pertinent to an individual episode, such as it's title and
	which files are associated with it.

	Typically this is just a "before" and "after" filename for a single file,
	but it can consist of multiple files. Multiple files are useful for keeping
	external subtitle-files with their video-files
	"""
	# TODO: Add flags for special episodes, such as pilots, Special (ala AniDB)
	# etc
	number = None	# E.g. "1" for 2x01
	title = ""

	def __init__(self, number, title):
		# Note that number can be explicity set to None by the caller, this
		# will be useful for general clean-up of filename that are not strictly
		# part of the season's sequence
		self.number = number
		self.title = title

# TODO: After having experimented a bit with objects, it's clear that Season
# and Episode should be combined in a way which allows trivial adding /
# retrival of Episode objects.
# From an Episode instance's point of view, how does it find out what season it
# belongs to? (Something which will probably be very desirable!) Perhaps
# something closer to "EpData.addEpisode(1, "Pilot")" and hiding the Episode
# class? .. but then how does the engine apply regexps and derive filename
# changes that need to take place?
# It comes down to an architecture decision: Is this purely reference data (as
# in the PERL version) or is it going to be something more?
#
# Is it possible to detect which class is accessing your functions? If so, then
# much of the complexity can be hidden - there would be a "global" store for
# episode data, which each parser attempts to populate. The global store tags
# each entry with some provenance (which parser added the entry), thus allowing
# some intelligent behaviour: Use data that causes the least change (but more
# than "no change").
# ---> Yes it is, the instance's symbol can be found via self.__class__.__name__
class Season:
	"""Container for sets of Episode instances."""
	number = None
	episodes = []

	def __init__(self, number):
		self.number = number
	
	def add(self, episode):
		# Check if episode already defined
		try:
			self[episode.number]
		except IndexError:
			logging.debug( "[Season %d] Adding episode %d" % (self.number, episode.number) )
			self.episodes.append(episode)
		else:
			raise Exception("Episode %d already present!" % episode.number)
	
	def getMinEpNum(self):
		return reduce(min, [x.number for x in self.episodes])

	def getMaxEpNum(self):
		return reduce(max, [x.number for x in self.episodes])

	def __getitem__(self, needle):
		"""Allows season[x] lookups"""
		for ep in [(x.number, x) for x in self.episodes]:
			if ep[0] is needle:
				return ep[1]
		raise IndexError


#season = Season(1)
#for index, filename in enumerate(get_file_list(os.getcwd())):
#	season.add(Episode(index, filename))
#
#print season


# Parser class experiment. Does it make sense to define an abstract class which
# is concretely defined multiple times by seperate blocks of code, and which is
# then instantiated once to consume data, is it actually any neater than having
# multiple functions defined?
class A:
	def talk(self):
		print "Fuckin' A!\n"

	def act(self):
		print "My name is %s, and I have this to say: " % self.__class__.__name__
		print vars(self.__class__)
		self.talk()

class B:
	pass

class a(A):
	def talk(self):
		print "aye?"

class aa(A):
	def talk(self):
		print "Aah, interesting point!"

class aaa(A):
	def talk(self):
		print "Aaargh! Not more 'a's!"
		for frame in traceback.extract_stack():
			print frame

class b(B):
	pass

class bb(B):
	pass

class bbb(B):
	pass

def classesDerivedFrom(BaseClass):
	"""Returns a list of all objects in the root scope which are subclasses of
	'BaseClass'

	>>>class A:
	... pass
	...
	>>>class a(A):
	... pass
	...
	>>>class aa(A):
	... pass
	...
	>>>classesDerivedFrom(A)
	[<class __main__.a at 0xb7dda11c>, <class __main__.aa at 0xb7dda1dc>]
	"""
	import __main__		# Handle for root scope

	foundClasses = [];

	for attribute in dir(__main__):
		try:
			handle = eval(attribute)
			if issubclass(handle, BaseClass) and handle is not BaseClass:
				foundClasses += [handle]
		except (TypeError, NameError):
			pass
	
	return foundClasses

class exampleClass:
	def __init__(self):
		# Create instances of all found classes and execute their talk() func
		instances = [x() for x in classesDerivedFrom(A)];
		[y.act() for y in instances]

myExClass = exampleClass();
