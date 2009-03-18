#!/usr/bin/perl
use warnings; use strict;
use Test::More;

my $kwalitee = join('::', qw(Test Kwalitee));

eval "require $kwalitee; $kwalitee->import()";
plan( skip_all => "$kwalitee not installed; skipping" ) if $@;
