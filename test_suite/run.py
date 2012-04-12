#!/usr/bin/env python
"""
Run all test-suites for `tvrenamer.pl`.

This script uses the following hungarian notation (because it's what the 
author is forced to use at work, call it habit)::

  g = global
  r = str
  l = list
  d = dict
  i = int
  f = float
  s = instance of type not listed above
  m = multiple types (i.e. changes depending on context / time)
  cls = Class object
  fnc = Function (more generally, anything callable)
  si = Iterable (typically a generator)
"""
__docformat__ = "restructuredtext en"

import os
import subprocess as sp

grBaseDir = os.path.abspath( os.path.dirname( __file__ ) )
grTVRenamer = os.path.abspath( os.path.join( grBaseDir, "..", "tvrenamer.pl" ) )

# -----------------------------------------------------------------------------
def iter_tests():
    """
    Find tests in directories adjacent to this script, or specified as script 
    arguments.

    Any directory containing an EXPECTED_RESULT file (which contains the STDOUT 
    a successful run of the test will produce).
    """
    import sys

    if sys.argv[1:]:
        lSearchDirs = list()
        for rArg in sys.argv[1:]:
            rDir = os.path.abspath( rArg )
            if not os.path.exists( rDir ):
                print "WARNING: Ignoring non-existant directory %r" % rDir
                continue
            lSearchDirs.append( rDir )
    else:
        lSearchDirs = [grBaseDir]

    for rSearchDir in lSearchDirs:
        for rDir, lDirs, lFiles in os.walk(rSearchDir):
            if "EXPECTED_RESULT" in lFiles:
                yield rDir

# -----------------------------------------------------------------------------
def run_test(rTestDir):
    """
    Run `tvrenamer.pl` within ``rTestDir`` (which is assumed to be in a clean 
    state) and verify that every line that appears in EXPECTED_RESULT also 
    appears in STDOUT. (STDOUT may contain lines not in EXPECTED_RESULT.)

    Files used:

        * EXPECTED_RESULT: Contents are compared against STDOUT, test has 
          failed if they differ.

        * OPTIONS: Text-file containing `tvrenamer.pl` options, as they would 
          be specified on a command line.
    """
    rOptsFile = os.path.join( rTestDir, "OPTIONS" )
    rOpts = ""

    if os.path.exists( rOptsFile ):
        with file( rOptsFile ) as sFH:
            rOpts = sFH.read().strip()

    sPH = sp.Popen(
            "%s --cache %s" % (grTVRenamer, rOpts),
            shell=True,
            stdin=sp.PIPE,
            stdout=sp.PIPE,
            stderr=sp.PIPE,
            cwd=rTestDir,
            universal_newlines=True)
    rSTDOUT, rSTDERR = sPH.communicate()

    if rSTDERR:
        # Test failed
        print ("%s failed\n%s\n" % (rTestDir, rSTDERR)) + ("-"*80)
        return

    with file( os.path.join(rTestDir, "EXPECTED_RESULT"), "rU" ) as sFH:
        iChecks = 0
        iPasses = 0
        for rExpected in sFH:
            iChecks += 1
            rExpected = rExpected.strip()
            if rExpected in rSTDOUT:
                iPasses += 1
            else:
                print "    Missing output: %r" % (rExpected)

    if iChecks == iPasses:
        print "    OK"
    else:
        print "    %s" % ("#" * 70)
        print "    %s" % rSTDOUT.replace("\n", "\n    ")

# -----------------------------------------------------------------------------
if __name__ == "__main__":
    for rTestDir in iter_tests():
        print rTestDir[len(grBaseDir):]
        run_test(rTestDir)
