#!/usr/bin/python -i

# RobM's TV Series Renamer

import os, glob

# TODO: Add a preferences system (using the pickle module to store and retrieve
# complex python data structures)
# TODO: Look into using urllib2 (a standard library) for grabbing online data
# TODO: Look into using the logging module, that's what it's called: logging

def prompt(question, default_answer):
	"""Gets input from a user, optionally letting them use a default by hitting
	return without entering anything"""
	answer = raw_input(question + " [" + default_answer +"]: ")
	if answer == "":
		return default_answer
	else:
		return answer

def finddirs(path):
	walk_generator = os.walk(path)
	

finddirs(os.getcwd())
