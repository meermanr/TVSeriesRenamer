#!/usr/bin/env python
# Update $version in tvrenamer.pl based on current date and highest version 
# number in change-log comments

import os
import re
import time
import sys

beta_release = False
if "--beta" in sys.argv[1:]:
    beta_release = True


p = os.popen("bash -c 'pushd .. >/dev/null; git ls-files -m trunk/tvrenamer.pl; popd >/dev/null'")
output = p.read()
p.close()
if len(output) > 0:
    print "tvrenamer.pl has uncommitted modifications!"
    exit(1);

with file("../trunk/tvrenamer.pl", "r") as fh:
    script = fh.read()

versions = []
for match in re.finditer("#\s*v(\d+)\.(\d+)\s", script):
    versions.append( (int(match.group(1)), int(match.group(2))) )
versions = sorted(versions)
release = versions[-1]
release = [ str(x) for x in release ]
release = ".".join(release)
release = "v" + release

today = time.strftime("%d %B %Y")

print "Updating --version info to %s (%s)" % (release, today)

# Note that the replacement string is processed by re.subn, and so must be 
# escaped *in addition to* being a 'raw' string
script, changes = re.subn(
    r'my \$version \= \"TV Series Renamer \d+\.\d+\\nReleased [^"]+\\n\"\; \# \{\{\{',
    r"""my $version = "TV Series Renamer %s\\nReleased %s\\n"; # {{{""" % (
            release,
            today,
            ),
    script
    )

if changes == 0:
    print "Release script was unable to update --version info, please fix it!"
    exit(2)

if changes > 1:
    print "Release script got confused by multiple '$version' lines in tvrenamer.pl, please update it."
    exit(3)

with file("../trunk/tvrenamer.pl", "w") as fh:
    fh.write(script)

if beta_release:
    dst = "tvrenamer.beta.pl"
else:
    dst = "tvrenamer.pl"

print "Uploading %s..." % dst
retval = os.system("rsync -P ../trunk/tvrenamer.pl robmeerman.co.uk:public_html/downloads/%s" % dst)
print "Done"

if retval == 0:
    print "Upload successful, tagging release"
    os.system("git add -u ../trunk/tvrenamer.pl")
    if beta_release:
        os.system("git commit -m 'Beta %s'" % release)
        os.system("git tag -f %s" % release)
    else:
        os.system("git commit -m 'Release %s'" % release)
        os.system("git tag %s" % release)
