#!/usr/bin/perl
# Test app for learning a bit about OOperl

package Person;

use strict;
use warnings;
use diagnostics;

my $Census = 0;

## The object constructor (simplistic version)
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	$Census++;
	$self->{NAME}	= undef;
	$self->{AGE}	= undef;
	$self->{PEERS}	= [];
	bless($self, $class);		# But see below
	return $self;
}

## Methods to access per-pbject data
# With args, they set the value, without they retrive it
sub name 
{
	my $self = shift;
	if (@_) { $self->{NAME} = shift }
	return $self->{NAME};
}

sub age
{
	my $self = shift;
	if (@_) { $self->{AGE} = shift }
	return $self->{AGE};
}

sub peers
{
	my $self = shift;
	if (@_) { @{$self->{PEERS}} = @_ }
	return @{$self->{PEERS}};
}

sub get_population
{
	return $Census;
}

sub DESTROY
{
	--$Census;
}

return 1; # Return true to indicate we're good to go!
