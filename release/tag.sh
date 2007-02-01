#!/bin/bash
# Tag a release

VERSION=$(grep 'my $version' tvrenamer.pl | sed -e 's/^.*\([0-9]\+\.[0-9]\+\).*$/\1/')

# Merge in changes (i.e. updated $version string)
diff ../trunk/tvrenamer.pl tvrenamer.pl | patch ../trunk/tvrenamer.pl
svn commit ../trunk/tvrenamer.pl -m "Released as v$VERSION"

# Tag release
svn mkdir ../tags/v$VERSION
svn cp ../trunk/tvrenamer.pl ../tags/v$VERSION/
svn commit ../tags/v$VERSION -m "Tagging release v$VERSION"
