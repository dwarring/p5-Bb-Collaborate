#!perl
use warnings;
use File::Spec;
use Test::More;
use English qw(-no_match_vars);

use lib '.';
use t::Elive;

use File::Spec;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval "use Test::Cmd";

if ( $EVAL_ERROR ) {
   my $msg = 'Test::Cmd required to run scripts';
   plan( skip_all => $msg );
}

plan(tests => 12);

my $script_name = 'elive_query';

my $cmd = Test::Cmd->new(prog => File::Spec->catfile(script => $script_name),
			 dir  => 'script',
			 fail => '$? != 0',
			 workdir => '',
    );
#
# try running script with --help
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, '--help' );
	diag("stderr:$stderr");
	diag("stdout:$stdout");
    ok($stderr eq '', "$script_name --help: no errors");
    ok($stdout =~ m{usage:}ix, "$script_name --help: stdout =~ 'usage:...''");
};
#
# try with invalid option
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, '--invalid-opt'  );

    ok($stderr =~ m{unknown \s+ option}ix, "$script_name invalid option error");
    ok($stdout =~ m{usage:}ix, "$script_name invalid option usage");

};

#
# invalid command
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, -c => 'blah blah' );

    ok($stderr =~ m{unrecognised \s command: \s blah}ixs, "$script_name -c '<invalid command>': error as expected");
    ok($stdout eq '', "$script_name -c '<invalid command>': no output");
};

#
# describe one of the entities: user
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, -c => 'describe user' );

    ok($stderr eq '', "$script_name -c 'describe user': no errors");
    ok($stdout =~ m{user: \s+ Elive::Entity::User .* userId \s+ : \s+ pkey \s+ Str}ixs, "$script_name -c 'describe user': looks like dump of users entity");

};

#
# describe unknown entity
#

do {
    my ( $stdout, $stderr ) = t::Elive->run_script($cmd, -c => 'describe crud' );

    ok($stderr =~ m{unknown \s+ entity: \s+ crud}ix, "$script_name: describe <unknown> error");
    ok($stdout eq '', "$script_name: describe <unknown> error - no output");
};

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	2)
	unless $auth && @$auth >= 3;

    my ($url, $user, $pass) = @$auth;

    
    do {
	my ( $stdout, $stderr ) = t::Elive->run_script(
	    $cmd,
	    $url,
	    -user => $user,
	    -pass => $pass,
	    -c => 'select serverDetailsId from serverDetails');
	diag("...run");
	diag("stderr:$stderr");
	diag("stdout:$stdout");
       
	ok($stderr =~ m{^connecting}i, "$script_name -c 'connecting...' message");
	ok($stdout =~ m{serverDetailsId .* \w+ }ixs, "$script_name -c expected select output");
	
    }
}
