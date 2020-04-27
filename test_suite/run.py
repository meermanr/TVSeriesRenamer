#!/usr/bin/env python
"""Run all tests for `tvrenamer.pl`."""
__docformat__ = "restructuredtext en"

import os
import sys
from cStringIO import StringIO
from subprocess import PIPE, Popen


BASE_DIR = os.path.abspath(os.path.dirname(__file__))
TVRENAMER = os.path.abspath(os.path.join(BASE_DIR, "..", "tvrenamer.pl"))


def to_stderr(s, indent=0):
    """Helper to write to stderr."""
    sys.stderr.write('%s%s\n' % ('    ' * indent, s))


def find_test_dirs():
    """
    Find tests in directories adjacent to this script, or specified as script
    arguments.

    Any directory containing an EXPECTED_RESULT file (which contains the STDOUT
    a successful run of the test will produce).
    """
    if len(sys.argv) > 1:
        search_dirs = []
        for arg in sys.argv[1:]:
            test_dir = os.path.abspath(arg)
            if not os.path.exists(test_dir):
                to_stderr("WARNING: Ignoring non-existent directory %s" %
                          test_dir)
                continue
            search_dirs.append(test_dir)
    else:
        search_dirs = [BASE_DIR]

    for search_dir in search_dirs:
        for test_dir, _, files in os.walk(search_dir):
            if "EXPECTED_RESULT" in files:
                yield test_dir


def run_test(test_dir):
    """
    Run `tvrenamer.pl` within ``test_dir`` (which is assumed to be in a clean
    state) and verify that every line that appears in EXPECTED_RESULT also
    appears in STDOUT. (STDOUT may contain lines not in EXPECTED_RESULT.)

    Files used:

        * EXPECTED_RESULT: Contents are compared against STDOUT, test has
          failed if they differ.

        * OPTIONS: Text-file containing `tvrenamer.pl` options, as they would
          be specified on a command line.
    """
    opts_file = os.path.join(test_dir, "OPTIONS")

    if os.path.exists(opts_file):
        with open(opts_file) as f:
            opts = f.read().strip()
    else:
        opts = ""

    tvr = Popen(
        "%s --cache %s" % (TVRENAMER, opts),
        shell=True,
        stdin=PIPE,
        stdout=PIPE,
        stderr=PIPE,
        cwd=test_dir,
        universal_newlines=True)
    out, err = tvr.communicate()

    if err:
        # Test failed
        to_stderr("%s failed\n%s\n%s" % (test_dir, err, "-" * 80))
        return False

    with open(os.path.join(test_dir, "EXPECTED_RESULT"), "rU") as f:
        checks = 0
        passes = 0
        for expected_line in (l.strip() for l in f.readlines()):
            checks += 1
            if expected_line in out:
                passes += 1
            else:
                to_stderr("Missing output: %s" % expected_line, 1)

    if checks == passes:
        to_stderr("OK", 1)
        return True
    else:
        to_stderr("%s" % ("#" * 70), 1)
        for line in StringIO(out).readlines():
            to_stderr("%s" % line.strip(), 1)
        return False


if __name__ == "__main__":
    yAllPass = True
    try:
        siDirs = sys.argv[1:] or find_test_dirs()
        for test_dir in siDirs:
            to_stderr(test_dir[len(BASE_DIR):])
            yPass = run_test(test_dir)
            yAllPass = yAllPass and yPass
    except KeyboardInterrupt:
        sys.exit(1)

    if yAllPass:
        sys.exit(0)
    else:
        sys.exit(1)
