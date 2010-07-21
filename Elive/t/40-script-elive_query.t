#!perl
use warnings;
use File::Spec;
use Test::More;
use Test::Exception;
use English qw(-no_match_vars);

use lib '.';
use t::Elive;

use File::Spec;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval "use Test::Script::Run";

if ( $EVAL_ERROR ) {
    my $msg = 'Test::Script::Run required to run scripts';
    plan( skip_all => $msg );
}

unless (${Test::Script::Run::VERSION} >= '0.04') {
    my $msg = "Test::Script::Run version (${Test::Script::Run::VERSION} < 0.04)";
    plan( skip_all => $msg );
} 

local ($ENV{TERM}) = 'dumb';

plan(tests => 17);

my $script_name = 'elive_query';

do {
    #
    # try running script with --help
    #

    my ( $result, $stdout, $stderr ) = run_script ($script_name, ['--help'] );

    ok($stderr eq '', "$script_name --help: no errors");
    ok($stdout =~ m{usage:}ix, "$script_name --help: stdout =~ 'usage:...''");
};

do {
    # 
    # try with invalid option
    #

    my ( $result, $stdout, $stderr ) = run_script($script_name, ['--invalid-opt']  );

    ok($stderr =~ m{unknown \s+ option}ix, "$script_name invalid option error");
    ok($stdout =~ m{usage:}ix, "$script_name invalid option usage");

};

do {
    #
    # invalid command
    #

    my ( $result, $stdout, $stderr ) = run_script($script_name, [-c => 'blah blah'] );

    ok($stderr =~ m{unrecognised \s command: \s blah}ixs, "$script_name -c '<invalid command>': error as expected");
    ok($stdout eq '', "$script_name -c '<invalid command>': no output");
};

do {
    #
    # describe one of the entities: user
    #

    my ($result, $stdout, $stderr) = run_script ($script_name, [-c => 'describe user']);

    ok($stderr eq '', "$script_name -c 'describe user': no errors");
    ok($stdout =~ m{user: \s+ Elive::Entity::User .* userId \s+ : \s+ pkey \s+ Str}ixs, "$script_name -c 'describe user': looks like dump of users entity");

};

do {
    #
    # describe unknown entity
    #

    my ( $result, $stdout, $stderr ) = run_script($script_name, [-c => 'describe crud'] );

    ok($stderr =~ m{unknown \s+ entity: \s+ crud}ix, "$script_name: describe <unknown> error");
    ok($stdout eq '', "$script_name: describe <unknown> error - no output");
};

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	7)
	unless $auth && @$auth >= 3;

    my ($url, $user, $pass) = @$auth;

    
    do {
	#
	# simple query on server details
	#
	my ( $result, $stdout, $stderr ) = run_script(
	    $script_name,
	    [$url,
	     -user => $user,
	     -pass => $pass,
	     -c => 'select serverDetailsId from serverDetails']);
       
	ok($stderr =~ m{^connecting}i, "$script_name -c 'connecting...' message");
	ok($stdout =~ m{serverDetailsId .* \w+ }ixs, "$script_name -c expected select output");
	
    };

    eval {require YAML};
    # YAML is a Elive prequesite
    die "unable to load YAML - can't continue: $@"
	if $@;

    do {
	#
	# simple query on server details - yaml dump of output
	#
	my ( $result, $stdout, $stderr ) = run_script(
	    $script_name,
	    [$url,
	     -user => $user,
	     -pass => $pass,
	     -dump => 'yaml',
	     -c => 'select serverDetailsId from serverDetails']);

       
	ok($stderr =~ m{^connecting}i, "$script_name -c 'connecting...' message");

	my $data;
	my @guff;

	lives_ok(sub {($data, @guff) = YAML::Load($stdout)}, 'output is parsable YAML');
	isa_ok($data, 'HASH', 'result');
	ok($data->{ServerDetails}[0]{serverDetailsId}, 'hash structure contains ServerDetails[0].serverDetailsId');

	ok(!@guff, 'single result returned');

    };

}
