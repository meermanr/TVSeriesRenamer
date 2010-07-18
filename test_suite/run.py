#!/usr/bin/env python
# Run tvrenamer.pl's test-suite

# This script uses the following hungarian notation (because it's what the 
# author is forced to use at work, call it habit):
#
#   g = global
#   r = str
#   l = list
#   d = dict
#   i = int
#   f = float
#   s = instance of type not listed above
#   m = multiple types (i.e. changes depending on context / time)

import os
import subprocess as sp

grBaseDir = os.path.abspath( os.path.dirname( __file__ ) )
grTVRenamer = os.path.abspath( os.path.join( grBaseDir, "..", "tvrenamer.pl" ) )

def iter_tests():
    for rDir, lDirs, lFiles in os.walk(grBaseDir):
        if "EXPECTED_RESULT" in lFiles:
            yield rDir

def run_test(rTestDir):
    sPH = sp.Popen(
            grTVRenamer,
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

if __name__ == "__main__":
    for rTestDir in iter_tests():
        print os.path.basename(rTestDir)
        run_test(rTestDir)
