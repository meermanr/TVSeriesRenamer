#!/usr/bin/python -i
# vim: set fileencoding=utf-8 :

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
	                  /   \\
	                B       C
	              /   \      \\
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

"""
class ProcureSourceFile(ProcureSource):
	pass

class ProcureSourceSTDIN(ProcureSource):
	pass
"""

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
		except Exception, inst:
			if inst.args[0] == "Giving up":
				pass
			else:
				raise

		if len(self.episode_data) > 0:
			self.logging.info("Got data on %d episodes" % len(self.episode_data) )

		# XXX A hack, do it properly, and do it in a more generic class that Website
		from Store import Store
		s = Store("Test")	# <-- Here's why this should be done earlier.
		for ep in self.episode_data:
			try:
				s.add_episode(ep)
			except Store.StoreError, inst:
				self.logging.warn("While processing episode '%s': %s" % (ep, inst.args[0]) )
				# Ignore and continue trying to populate the store
				# TODO: Emit warning
				pass
		s.dump()
		import __main__
		__main__.store = s

	def downloadURL(self, URL, already_quoted=False):
		import urllib, urllib2

		if not already_quoted:
			URL = URL[0:8] + urllib.quote(URL[8:])

		try:
			self.logging.debug("Fetching '%s'" % URL)
			f = urllib2.urlopen(URL)
			self.data = f.read()
			self.lasturl = URL
		except urllib2.HTTPError, inst:
			self.logging.error("%d %s while trying to retrieve %s" % (inst.code, inst.msg, inst.filename) )
			for key in inst.headers:
				self.logging.debug("%s: %s" % (key, inst.headers[key]) )
			raise

	def simplified_html(self):
		import re
		return re.sub("<\s*([^> ]+)[^>]*?>", "<\\1>", self.data)

	def decompress_gzipped_response(self):
		import gzip, StringIO

		# gzip works on file-like objects, so we'll wrap our memory buffer in
		# StringIO
		f = StringIO.StringIO(self.data)
		g = gzip.GzipFile(fileobj=f)

		self.data = g.read()

		g.close()
		f.close()

		self.logging.debug("Decompressed response. %d bytes" % len(self.data) )
		self.logging.debug(self.data.splitlines()[0])


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

"""
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
"""


class ProcureSourceWebsiteAniDB(ProcureSourceWebsite):

	root_url = "http://anidb.net/perl-bin/"
	page_list = []	# List of URLs-worth-investigating from search results

	def search(self):
		import urllib

		if self.page_list:
			self.logging.error("Not implemented yet. Would have investigated next search result, or raised an exception if no uninvestigated results exist")
			pass
		else:
			search_url = self.root_url + "animedb.pl?show=animelist&adb.search=%s&do.search=search" % urllib.quote_plus(self.series_name)
			self.logging.debug("Search URL: %s" % search_url)
			self.downloadURL(search_url, already_quoted=True)
			# TODO: Open a "bug" report with AniDB.info - their HTTP headers should
			# report that the content type is compressed - NOT text/html. It's not.
			self.decompress_gzipped_response()

			import re
			# List of patterns, increasing in fuzziness
			patterns = []
			patterns.append('<a href="(.*?)">%s</a>' % self.series_name)

			# Compile patterns
			patterns = [re.compile(p, re.MULTILINE) for p in patterns]

			# Collect results of applying all patterns
			for p in patterns:
				self.page_list.extend( re.findall(p, self.data) )

			# Remove duplicates (more common than you'd think)
			# The awesome one-liner works by creating a second list which is offset
			# by one (achieved by prepending a None element) so that zip()
			# effectively produces pairs of neighbours (n, n+1). We then filter out
			# all the cases where n == n+1
			self.page_list = sorted(self.page_list)
			self.page_list = [ x[0] for x in zip(self.page_list, [None]+self.page_list) if x[0] != x[1] ]

			# Clean-up: &amp; -> &
			self.page_list = [ re.sub("&amp;", "&", p) for p in self.page_list ]

			# Use results
			if self.page_list:
				if len(self.page_list) > 1:
					self.logging.info("Found %d matches!" % len(self.page_list) )
					self.logging.warn("Only first match will be used, fallback not yet implemented")
				else:
					self.logging.info("Found match!")

				self.downloadURL("%s%s" % (self.root_url, self.page_list[0]), already_quoted=True)
				self.decompress_gzipped_response()

			else:
				self.logging.debug("No match found in search results. Giving up.")
				raise Exception("Giving up")

	def parse(self):
		import re

		data = self.simplified_html()

		# Example data
		#  <tr>
		#          <td><a>7</a></td>
		#          <td>
		#                  <span>
		#                          
		#                  </span>
		#                  <label>The Assassin of the Mist! <span>( Zabójca we mgle / 霧の暗殺者！ / นักฆ่าในสายหมอก / L`assassin dans la brume / Kiri no Ansatsusha! )</span></label>
		#          </td>
		#          <td>25m</td>
		#          <td>14.11.2002</td>
		#  </tr>



		patterns = []
		patterns.append('(?x)<tr>\s*<td><a>(?P<EpisodeNumber>\d+)</a></td>\s*<td>\s*<span>[^<]*</span>\s*<label>(?P<EpisodeTitle>[^<]*)<span>(?P<AltEpTitles>[^<]*)</span></label>\s*</td>\s*<td>(?P<duration>[^<]*)</td>\s*<td>(?P<aired>[^<]*)</td>\s*</tr>')

		# Compile patterns
		patterns = [re.compile(p, re.MULTILINE | re.DOTALL) for p in patterns]

		# Collect results of applying all patterns
		#
		# TODO: Record source for use with Store class - source should be
		# unique to the URL in someway (i.e. so that multiple search results
		# can be added)
		for p in patterns:
			for m in re.finditer(p, data):
				if m is None: continue
				d = {"SeasonNumber": 1, "Source": "AniDB"}	 # AniDB doesn't "do" seasons
				for k in ["EpisodeNumber", "EpisodeTitle", "AltEpTitles", "duration", "aired"]:
					try:
						d[k] = m.group(k)
					except IndexError:
						pass
				self.episode_data.append(d)


if __name__ == "__main__":
	import glob
	for plugin in glob.glob("Procure_plugins/*.py"):
		if plugin[-12:] == "/__init__.py": continue
		plugin = plugin[0:-3]	# Strip ".py"
		plugin = plugin.replace("/", ".")
		print "Importing", plugin
		exec("from %s import *" % plugin)

	# Some test-cases
	procure = Procure("Naruto")

