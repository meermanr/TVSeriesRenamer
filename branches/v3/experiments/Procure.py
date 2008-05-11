#!/usr/bin/python

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
	
	def __init__(self, series):
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
		self.instances = [x(series) for x in class_list]

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

	logging	= None
	series	= None

	def __init__(self, series):
		import thread, logging

		Thread.__init__(self)

		self.logging = logging.getLogger(self.__class__.__name__ )
		self.series = series


	def run(self):
		"""
		Thread payload goes here.

		Note: To begin execution of this thread, call start(), which has been
		inherited from threading.Thread
		"""

		import time
		self.logging.debug("Pretending to search for %s" % self.series)
		time.sleep(1)

class ProcureSourceSTDIN(ProcureSource):
	pass

class ProcureSourceWebsite(ProcureSource):
	pass

class ProcureSourceWebsiteEpGuides(ProcureSourceWebsite):
	pass

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
