#!/usr/bin/python

import logging
logging.addLevelName(logging.DEBUG,	"[36mDEBUG[0m")
logging.addLevelName(logging.WARN,	"[33mWARN[0m")
logging.addLevelName(logging.ERROR,	"[31mERROR[0m")
logging.addLevelName(logging.INFO,	"[32mINFO[0m")

class Procure():
	"""
	A class for procuring series and season data from various sources, such as
	websites, static files and user input.

	This class automatically finds classes derived from ProcureSource, and
	instantiates those that do not have subclasses (i.e. are the leaf nodes of
	an inheritance tree). These instances are then run and eventually
	harvested.
	"""

	logging = None
	instances = []
	
	def __init__(self, series_name):
		"""
		Find all classes dervied (indirectly) from ProcureSource and
		instantiate them

		input series: (String) Title of series to procure data about
		"""
		import logging

		logging.basicConfig(level=logging.DEBUG)	# Optional, defaults to warning
		self.logging = logging.getLogger(self.__class__.__name__)

		class_list = [ProcureSource]	# Root class
		subclass_list = []
		while True:
			for c in class_list:
				# Find subclasses of each class
				s = type(c).__subclasses__(c)
				if len(s) > 0:
					subclass_list.extend(s)
				else:
					# No subclasses, therefore this is the leaf node. We found
					# what we were looking for
					subclass_list.append(c)

			if class_list == subclass_list:
				# No expansion took place, we have all leaf classes
				break
			else:
				class_list = subclass_list
				subclass_list = []

		self.logging.info("Found %d sources" % len(class_list))
		self.logging.debug([c.__name__ for c in class_list])
		self.instances = [x(series_name) for x in class_list]

		self.logging.info("Querying sources")
		[x.start() for x in self.instances]

		[x.join() for x in self.instances]
		self.logging.info("All queries complete")





from threading import Thread
class ProcureSource(Thread):
	"""
	Template class for Procure sources, see Procure class.

	Note: Be aware that only leaf nodes of a class tree are instatiated by
	Procure. For example, if you had the following tree of class inheritance:
	                    A
	                  /   \
	                B       C
	              /   \      \
	            D       E      F

	Only classes D, E and F would be instantiated. A, B and C would not be.
	"""

	logging			= None
	series_name		= None
	episode_data	= []

	def __init__(self, series_name):
		import thread, logging

		Thread.__init__(self)

		self.logging = logging.getLogger(self.__class__.__name__ )
		logging.addLevelName(logging.DEBUG, "[36mDEBUG[0m")
		logging.addLevelName(logging.WARN, "[33mWARN[0m")
		logging.addLevelName(logging.ERROR, "[31mERROR[0m")
		logging.addLevelName(logging.INFO, "[32mINFO[0m")

		self.series_name = series_name


	def run(self):
		"""
		Thread payload goes here.

		Note: To begin execution of this thread, call start(), which has been
		inherited from threading.Thread
		"""

		import time
		self.logging.debug("Pretending to search for %s" % self.series_name)
		time.sleep(1)

class ProcureSourceFile(ProcureSource):
	pass

class ProcureSourceSTDIN(ProcureSource):
	pass

class ProcureSourceWebsite(ProcureSource):
	"""
	Website data source template class.
	"""

	data = ""
	lasturl = ""

	def run(self):
		import urllib2
		try:
			self.search()
			self.parse()
		except urllib2.HTTPError:
			self.logging.error("Aborting due to errors")

		if len(self.episode_data) > 0:
			self.logging.info("Got data on %d episodes" % len(self.episode_data) )

	def downloadURL(self, URL):
		import urllib, urllib2

		URL = URL[0:8] + urllib.quote(URL[8:])

		try:
			f = urllib2.urlopen(URL)
			self.data = f.read()
			self.lasturl = URL
		except urllib2.HTTPError, inst:
			self.logging.error("%d %s while trying to retrieve %s" % (inst.code, inst.msg, inst.filename) )
			for key in inst.headers:
				self.logging.debug("%s: %s" % (key, inst.headers[key]) )
			raise

	def search(self):
		"""
		Obtain an URL which points at the series data we are looking for
		"""
		self.logging.debug("Pretending to query a website")

	def parse(self):
		"""
		Parse the data downloaded from the URL obtained via self.search()
		"""
		self.logging.debug("Pretending to parse the response")

class ProcureSourceWebsiteEpGuides(ProcureSourceWebsite):
	def search(self):
		import re
		short_name = re.sub("(?:The\s+)?(.*?)(?:, The)?", "\\1", self.series_name)
		short_name = re.sub("\s+", "", short_name)
		self.downloadURL("http://epguides.com/%s" % short_name)

	def parse(self):
		import re

		# Groupings:
		#  1: Episode number
		#  2: Episode title
		patterns = dict()
		patterns["normal"]	= re.compile("^\s*\d+\.\s+(\d+)-\s*(\d+)(?:\s+\S+){4}\s+<[^>]+>(.*)<[^>]+>$")
		patterns["pilot"]	= re.compile("^\s+(P)- (1)\s+<[^>]+>(.*)<[^>]+>$")

		for l in self.data.splitlines():
			for p in patterns:
				m = re.match(patterns[p], l)
				if m:
					self.episode_data.append( m.groups() )


class ProcureSourceWebsiteAniDB(ProcureSourceWebsite):
	pass


if __name__ == "__main__":
	import glob
	for plugin in glob.glob("Procure_plugins/*.py"):
		if plugin[-12:] == "/__init__.py": continue
		plugin = plugin[0:-3]	# Strip ".py"
		plugin = plugin.replace("/", ".")
		print "Importing", plugin
		exec("from %s import *" % plugin)

	# Some test-cases
	procure = Procure("Smallville")

