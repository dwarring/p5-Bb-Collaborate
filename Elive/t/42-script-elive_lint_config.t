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

eval "use Test::Cmd";

if ( $EVAL_ERROR ) {
   my $msg = 'Test::Cmd required to run scripts';
   plan( skip_all => $msg );
}

plan(tests => 5);

my $script_name = 'elive_lint_config';

my $cmd = Test::Cmd->new(prog => File::Spec->catfile(script => $script_name),
			 dir  => 'script',
			 fail => '$? != 0',
			 workdir => '',
    );
#
#
# try running script with --help
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, '--help' );
	diag("stderr:$stderr");
	diag("stdout:$stdout");
    ok($stderr eq '', "$script_name --help: stderr empty");
    ok($stdout =~ m{usage:}ix, "$script_name --help: stdout =~ 'usage:...''");
};
#
# try with invalid option
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, '--invalid-opt' );

    ok($stderr =~ m{unknown \s+ option}ix, "$script_name invalid option message");
    ok($stdout =~ m{usage:}ix, "$script_name invalid option usage");

};

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	1)
	unless $auth && @$auth;

    ok(1, 'dummy test');

}
