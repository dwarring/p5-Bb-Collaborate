#!perl -T
use strict;
use warnings;
use Test::More;

use_ok('Elive::DAO'); # to get version
use_ok('Elive::StandardV2'); # to get version

diag( "Testing Elive::StandardV2 $Elive::StandardV2::VERSION, Elive::DAO $Elive::DAO::VERSION, Perl $], $^X" );

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
