#!perl
use strict;
use warnings;
use Test::More;

use Elive; # to get version

diag( "Testing Elive $Elive::VERSION, Perl $], $^X" );

my $MODULE = 'Test::Strict';
eval "use $MODULE";
plan skip_all => "$MODULE not available for strict tests"
    if $@;

all_perl_files_ok( 'lib', 'script' );
