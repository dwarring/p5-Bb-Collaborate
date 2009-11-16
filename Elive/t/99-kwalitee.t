#!/usr/bin/perl
use warnings; use strict;

my $kwalitee = join('::', qw(Test Kwalitee));

eval "require $kwalitee; $kwalitee->import()";
print "1..0 # SKIP $kwalitee not installed; skipping\n"
    if $@;
