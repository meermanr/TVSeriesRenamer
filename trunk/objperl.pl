#!/usr/bin/perl
# Test app for learning a bit about OOperl

use Person;

use strict;
use warnings;
use diagnostics;

my $kitten = Person->new();
$kitten->name("Vicky");
$kitten->age("23");
$kitten->peers(["Sar", "Ficedula", "Colin"]);

print $kitten->get_population;
