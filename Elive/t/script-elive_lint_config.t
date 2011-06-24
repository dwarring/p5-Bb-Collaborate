#!perl
use strict;
use warnings;
use File::Spec;
use Test::More;
use English qw(-no_match_vars);

use lib '.';
use t::Elive;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval "use Test::Script::Run 0.04";

if ( $EVAL_ERROR ) {
    my $msg = 'Test::Script::Run required to run scripts';
    plan( skip_all => $msg );
}

local ($ENV{TERM}) = 'dumb';

plan(tests => 4);

my $script_name = 'elive_lint_config';

#
# try running script with --help
#

do {
    my ( $result, $stdout, $stderr ) = run_script($script_name, ['--help'] );
    is($stderr, '', "$script_name --help: stderr empty");
    ok($stdout =~ m{usage:}ix, "$script_name --help: stdout =~ 'usage:...''");
};

#
# try with invalid option
#

do {
    my ( $result, $stdout, $stderr ) = run_script($script_name, ['--invalid-opt'] );

    ok($stderr =~ m{unknown \s+ option}ix, "$script_name invalid option message");
    ok($stdout =~ m{usage:}ix, "$script_name invalid option usage");

};

