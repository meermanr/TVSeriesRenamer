#!/usr/bin/python
"""
Draft implementation of the episode-store
"""

class Store():
	"""
	Holds all episode data related to a particular series. This therefore can
	include multiple seasons
	"""

	class StoreError(Exception):
		pass
	
	series_name = None
	data = []

	# This will contain an episode dictionary, which will in turn contain a
	# dictionary of alternative episode data. Example:
	# seasons = {
	# 			1: {
	#   				1: {"EpGuides": <ep-data>, "TV.com": <ep-data>}
	# 					2: {"EpGuides": <ep-data>}
	# 					3: {"EpGuides": <ep-data>, "TV.com": <ep-data>}
	# 				}
	# 			2:
	# 				{
	# 					1: {"TV.com": <ep-data>}
	#   				2: {"EpGuides": <ep-data>, "TV.com": <ep-data>, "TV.com-alt": <ep-data>}
	# 					3: {"EpGuides": <ep-data>, "TV.com": <ep-data>}
	# 				}
	# 			}
	seasons = {}

	sources = {}
	

	def __init__(self, series_name):
		"Creates a new series data store for the named series"
		self.series_name = series_name

	def add_episode(self, data):
		"""
		Where data is a dictionary containing the following keys:

		  * SeasonNumber
		  * EpisodeNumber
		  * EpisodeTitle
		  * Source

		If these keys are missing, an exception is raised. Extra keys are
		allowed.

		Source should be a unique string identifier of where the data
		originates from. This will be useful when there are multiple hits from
		the same website (perhaps because the series name is vague).
		"""
		# Sanity-check input
		required_keys_and_types = [
				("SeasonNumber", type(1)),
				("EpisodeNumber", type(1)),
				("EpisodeTitle", type("")),
				("Source", type(""))
				]
		keys = data.keys()
		for key, required_type in required_keys_and_types:
			if key not in keys:
				raise self.StoreError("Required key '%s' not present in supplied data, rejecting." % key)
			elif type(data[key]) is not required_type:
				exception = self.StoreError("Required key %s present, but value is not of type %s (was %s), rejecting." % (key, required_type, type(data[key])) )
				if required_type is type(1):
					# Attempt conversion
					try:
						data[key] = int(data[key])
					except:
						raise exception
				else:
					# Complain
					raise exception

		# Input OK, keep it
		self.data += [ data ]

	def dump(self):
		import pprint, re
		print self.by_season()
		print self.by_source()
		print self.by_episode()
		print self.by_title(re.compile("Are"))

	def _by_generic(self, key, filter=None):
		import re
		l = []
		for datum in self.data:
			if filter is not None:
				# Perform a check
				if type(filter) is type(re.compile("")):
					if not re.search(filter, datum[key]):
						continue
				elif filter != datum[key]:
					continue


			# Still here? Then this one we want!
			l += [ (datum[key], datum) ]
		l.sort()
		l = [ d for (x, d) in l ]
		return l

	def by_season(self, season=None):
		return self._by_generic("SeasonNumber", season)

	def by_source(self, source=None):
		return self._by_generic("Source", source)

	def by_episode(self, episode=None):
		return self._by_generic("EpisodeNumber", episode)

	def by_title(self, title=None):
		return self._by_generic("EpisodeTitle", title)


if __name__ == "__main__":
	class C():
		def doit(self, s):
			# Test for finding caller
			s.add_episode({"SeasonNumber": 1, "EpisodeNumber": 1, "EpisodeTitle": "Hello", "Source": "1test"})
			s.add_episode({"SeasonNumber": 1, "EpisodeNumber": 2, "EpisodeTitle": "There", "Source": "1test"})
			s.add_episode({"SeasonNumber": 1, "EpisodeNumber": 3, "EpisodeTitle": "How", "Source": "2test"})
			s.add_episode({"SeasonNumber": 2, "EpisodeNumber": 1, "EpisodeTitle": "Are", "Source": "2test"})
			s.add_episode({"SeasonNumber": 2, "EpisodeNumber": 2, "EpisodeTitle": "You", "Source": "2test"})
			s.add_episode({"SeasonNumber": 2, "EpisodeNumber": 3, "EpisodeTitle": "Doing", "Source": "0test"})
			s.add_episode({"SeasonNumber": 3, "EpisodeNumber": 4, "EpisodeTitle": "Today?", "Source": "0test"})

	s = Store("Test")
	c = C()
	c.doit(s)

	s.dump()
