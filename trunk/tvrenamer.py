#!/usr/bin/python -i 

# RobM's TV Series Renamer

import os, glob, logging

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


season = Season(1)
for index, filename in enumerate(get_file_list(os.getcwd())):
	season.add(Episode(index, filename))

print season
