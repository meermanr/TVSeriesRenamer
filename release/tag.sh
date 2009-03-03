#!/bin/bash
# Tag a release

# Quit if any child returns an error
trap 'exit $?' ERR

# We can't assume this when called from DOS
cd ~/projects/tvrenamer_pl/release

VERSION=$(grep 'my $version' tvrenamer.pl | sed -e 's/^.*\([0-9]\+\.[0-9]\+\).*$/\1/')

if [ -d ../tags/v$VERSION ]; then
    echo Release v$VERSION already tagged!>&2
    exit 2
fi

# Merge in changes (i.e. updated $version string)
cp tvrenamer.pl ../trunk/tvrenamer.pl
git commit ../trunk/tvrenamer.pl -m "Released as v$VERSION"

# Tag release
git tag -a "v$VERSION" -m ""
