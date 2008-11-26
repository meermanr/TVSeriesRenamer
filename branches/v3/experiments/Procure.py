#!/usr/bin/python -i
# vim: set fileencoding=utf-8 :

import logging
logging.addLevelName(logging.DEBUG,	"[36mDEBUG[0m")
logging.addLevelName(logging.WARN,	"[33mWARN[0m")
logging.addLevelName(logging.ERROR,	"[31mERROR[0m")
logging.addLevelName(logging.INFO,	"[32mINFO[0m")

def lookup_series(series_name):
	"""
	Returns a Store object containing episode data related to series_name.

	This is achieved by finding all sub-classess of ProcureSource and
	instantiating "leaves" (of the inheritance tree), running them (they're
	threads), waiting for them to complete, and then combining their results.

	input series: (String) Title of series to procure data about
	"""
	import logging
	from Store import Store

	logging.basicConfig(level=logging.DEBUG)	# Optional, defaults to warning
	log = logging = logging.getLogger("Lookup Series %s" % series_name)

	class_list = [ProcureSource]	# Root class

	# Get a list of all modules
	import __main__, inspect
	for varname in dir(__main__):
		var = getattr(__main__, varname)
		if not inspect.ismodule(var): continue
		if "__file__" not in dir(var): continue
		if "plugin" not in var.__file__: continue

		# Therefore var refers to the plugins package (a module composed of
		# modules)
		plugins = var

		for varname2 in dir(plugins):
			var2 = getattr(plugins, varname2)
			if inspect.ismodule(var2):
				
				# So now we're looking at one of the plugin modules
				plugin = var2

				if "Procure" in dir(plugin):
					plugin_imported_module = getattr(plugin, "Procure")
					print plugin_imported_module
					if inspect.ismodule(plugin_imported_module):
						if "ProcureSource" in dir(plugin_imported_module):
							plugin_imported_baseclass = getattr(plugin_imported_module, "ProcureSource")
							print plugin_imported_baseclass
							if inspect.isclass(plugin_imported_baseclass):
								class_list.append(plugin_imported_baseclass)
								continue

				if "ProcureSource" in dir(plugin):
					plugin_imported_baseclass = getattr(plugin, "ProcureSource")
					print plugin_imported_baseclass
					if inspect.isclass(plugin_imported_baseclass):
						class_list.append(plugin_imported_baseclass)
						continue

	print class_list

	import pdb; pdb.set_trace()

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

	log.info("Found %d sources" % len(class_list))
	log.debug([c.__name__ for c in class_list])
	instances = [x(series_name) for x in class_list]

	import sys
	sys.exit()

	log.info("Querying sources")
	for x in instances: x.start()

	[x.join() for x in instances]
	log.info("All queries complete")

	log.info("Harvesting episode data")
	store = Store(series_name)
	for x in instances:
		print x, len(x.episode_data)
		for ep in x.episode_data:
			try:
				store.add_episode(ep)
			except Store.StoreError, inst:
				log.warn("While processing episode '%s': %s" % (ep, inst.args[0]) )
				pass
	log.info("Got %d data-points" % len(store.by_episode()))

	return store


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

	# Not used, just for clarity
	logging			= None
	series_name		= None
	episode_data	= None

	def __init__(self, series_name):
		import thread, logging

		Thread.__init__(self)

		self.logging = logging.getLogger(self.__class__.__name__ )
		logging.addLevelName(logging.DEBUG, "[36mDEBUG[0m")
		logging.addLevelName(logging.WARN, "[33mWARN[0m")
		logging.addLevelName(logging.ERROR, "[31mERROR[0m")
		logging.addLevelName(logging.CRITICAL, "[31mERROR[0m")
		logging.addLevelName(logging.INFO, "[32mINFO[0m")

		self.series_name = series_name
		self.episode_data = []


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
		for i, html in enumerate(self.search()):
			try:
				self.parse(html, "%s-%d" % (self.__class__.__name__, i) )
			except urllib2.HTTPError:
				self.logging.error("Aborting due to errors")

		if len(self.episode_data) > 0:
			self.logging.info("Got data on %d episodes" % len(self.episode_data) )


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

	def simplified_html(self, html_in=None):
		"""
		Strips all attribute paramaters from HTML source (e.g. "<a href=...>" becomes "<a>")

		If html_in is not provided, self.data is used instead.
		"""
		import re
		if html_in is None: html_in = self.data
		return re.sub("<\s*([^> ]+)[^>]*?>", "<\\1>", html_in)

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
		A generator which finds, fetches and yields HTML pages for parse().
		"""
		self.logging.debug("Pretending to query a website")
		raise StopIteration

	def parse(self, html, source):
		"""
		Parse HTML provided by search(), and add found episodes to self.episode_data

		"source" is a unique name for the HTML, this is used to distinguish
		hits from multiple pages.
		"""
		self.logging.debug("Pretending to parse the response")

class ProcureSourceWebsiteEpGuides(ProcureSourceWebsite):
	def search(self):
		import re
		short_name = re.sub("(?:The\s+)?(.*?)(?:, The)?", "\\1", self.series_name)
		short_name = re.sub("\s+", "", short_name)
		self.downloadURL("http://epguides.com/%s" % short_name)
		yield self.data
		raise StopIteration

	def parse(self, html, source):
		import re

		# Groupings
		# TODO: Pilots will cause a problem, because they don't have a season number
		patterns = dict()
		patterns["normal"]	= re.compile("^\s*(?P<AbsoluteEpisodeNumber>\d+)\.\s+(?P<SeasonNumber>\d+)-\s*(?P<EpisodeNumber>\d+)(?:\s+\S+){4}\s+<[^>]+>(?P<EpisodeTitle>.*)<[^>]+>$")
		patterns["pilot"]	= re.compile("^\s+(P)- (?P<EpisodeNumber>1)\s+<[^>]+>(?P<EpisodeTitle>.*)<[^>]+>$")

		# Collect results of applying all patterns
		for l in html.splitlines():
			for i, key in enumerate(patterns.keys()):
				p = patterns[key]
				for m in re.finditer(p, l):
					if m is None: continue
					d = {"Source": "%s-%d" % (source, i)}
					for k in ["SeasonNumber", "EpisodeNumber", "EpisodeTitle", "AbsoluteEpisodeNumber"]:
						try:
							d[k] = m.group(k)
						except IndexError:
							pass
					self.episode_data.append(d)


class ProcureSourceWebsiteAniDB(ProcureSourceWebsite):

	root_url = "http://anidb.net/perl-bin/"
	page_list = []	# List of URLs-worth-investigating from search results

	def search(self):
		import urllib

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
		patterns.append('<a href="(.*?)">%s, The</a>' % self.series_name)
		patterns.append('<a href="(.*?)">%s, A</a>' % self.series_name)

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

		# Yield results
		if self.page_list:
			if len(self.page_list) > 1:
				self.logging.info("Found %d matches!" % len(self.page_list) )
			else:
				self.logging.info("Found match!")

			for page in self.page_list:
				self.downloadURL("%s%s" % (self.root_url, self.page_list[0]), already_quoted=True)
				self.decompress_gzipped_response()
				yield self.data

		else:
			self.logging.debug("No match found in search results. Giving up.")

		raise StopIteration

	def parse(self, html, source):
		import re

		data = self.simplified_html(html)

		# Example data
		#  <tr>
		#          <td><a>7</a></td>
		#          <td>
		#                  <span>
		#                          
		#                  </span>
		#                  <label>The Assassin of the Mist! <span>( Zabójca we mgle / 霧の暗殺者！ / นักฆ่าในสายหมอก / L`assassin dans la brume / Kiri no Ansatsusha! )</span></label>
		#         </td>
		#         <td>25m</td>
		#         <td>14.11.2002</td>
		# </tr>

		patterns = []
		patterns.append('(?x)<tr>\s*<td><a>(?P<EpisodeNumber>\d+)</a></td>\s*<td>\s*<span>[^<]*</span>\s*<label>(?P<EpisodeTitle>[^<]*)<span>(?P<AltEpTitles>[^<]*)</span></label>\s*</td>\s*<td>(?P<duration>[^<]*)</td>\s*<td>(?P<aired>[^<]*)</td>\s*</tr>')

		# Compile patterns
		patterns = [re.compile(p, re.MULTILINE | re.DOTALL) for p in patterns]

		# Collect results of applying all patterns
		for i, p in enumerate(patterns):
			for m in re.finditer(p, data):
				if m is None: continue
				d = {"SeasonNumber": 1, "Source": "%s-%d" % (source, i)}	 # AniDB doesn't "do" seasons
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
		#exec("from %s import *" % plugin)
		exec("import %s" % plugin)

	# Some test-cases
	store = lookup_series("Futurama")
	#store.dump(store.by_episode())

