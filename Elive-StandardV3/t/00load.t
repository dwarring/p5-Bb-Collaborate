#!perl -T
use strict;
use warnings;
use Test::More;

use_ok('Elive::DAO'); # to get version
use_ok('Elive::StandardV3'); # to get version

diag( "Testing Elive::StandardV3 $Elive::StandardV3::VERSION, Elive::DAO $Elive::DAO::VERSION, Perl $], $^X" );

my $MODULE = 'Test::Strict';
eval "use $MODULE";
if ($@) {
    diag "$MODULE not available for strict tests";
    done_testing();
}
else {
    all_perl_files_ok( 'lib');
}

BAIL_OUT("unable to compile - aborting further tests")
    unless Test::More->builder->is_passing;
