#!perl -T
use warnings; use strict;
use Test::More tests => 62;
use Test::Exception;
use Test::Warn;
use Test::Builder;

use lib '.';
use t::Elive;

use Elive;
use Elive::Entity::Session;

use XML::Simple;

use Carp; $SIG{__DIE__} = \&Carp::confess;
use Carp; $SIG{__WARN__} = \&Carp::cluck;

our $t = Test::Builder->new;
our $class = 'Elive::Entity::Session' ;

our $connection;

ok($class->can('start')
   && $class->can('seats')
   && $class->can('participants')
   && $class->can('meeting')
   , 'delegation sanity');

lives_ok(sub {
    $class->_readback_check(
	{id => 12345, name => 'as expected'},
	[{id => 12345, meeting => {meetingId => 12345, name => 'as expected'}}]
	)}, 'readback on valid data -lives');

#
# meeting password is not echoed in response
#
lives_ok(sub {
    $class->_readback_check(
	{id => 12345, name => 'as expected', password=>'ssshhh!'},
	[{id => 12345, meeting => {meetingId => 12345, name => 'as expected', password => ''}}]
	)}, 'readback ignores blank password');

dies_ok(sub {
    $class->_readback_check(
	{id => 12345, name => 'expected meeting name'},
	[{id => 12345, meeting => {meetingId => 12345, name => 'whoops!'}}]
	)}, 'readback on invalid sub-record data - dies');

dies_ok(sub {
    $class->_readback_check(
	{id => 12345, name => 'as expected'},
	[{id => 99999, meeting => {meetingId => 12345, name => 'as expected'}}]
	)}, 'readback on invalid primary key - dies');

dies_ok(sub {
    $class->_readback_check(
	{id => 12345, name => 'as expected'},
	[{id => 12345, meeting => {meetingId => 9999, name => 'as expected'}}]
	)}, 'readback on valid sub-record primary key - dies');

lives_ok( sub {
    $class->_readback_check(
	{id => 12345, participants => 'bob=3;alice=2'},
	[{id => 12345, participantList => {meetingId => 12345, participants => 'alice=2;bob=3'}}]
	)}, 'readback is order independant');

lives_ok( sub {
    $class->_readback_check(
	{id => 12345, participants => 'alice=2;bob=3'},
	[{id => 12345, participantList => {meetingId => 12345, participants => 'alice=2;bob=3'}}]
	)}, 'readback with expected recipients - lives');

dies_ok( sub {
    $class->_readback_check(
	{id => 12345, participants => 'bob=3;alice=2'},
	[{id => 12345, participantList => {meetingId => 12345, participants => 'alice=2'}}]
	)},
	 'readback with missing participants - dies');

dies_ok( sub {
    $class->_readback_check(
	{id => 12345, participants => 'bob=3;alice=2'},
	[{id => 12345, participantList => {meetingId => 12345, participants => 'alice=2;bob=3;gatecrasher=3'}}]
	)}, 'readback with extraneous participants - dies');

my $session_start = time();
my $session_end = $session_start + 900;

$session_start .= '000';
$session_end .= '000';

my %insert_data = (
    name => 'test, generated by t/soap-session.t',
    password => 'test', # what else?
    start =>  $session_start,
    end => $session_end,
    facilitatorId => 'user_tba',
    privateMeeting => 1,
    costCenter => 'testing',
    moderatorNotes => 'test moderator notes. Here are some entities: & > <',
    userNotes => 'test user notes; some more entities: &gt;',
    recordingStatus => 'remote',
    raiseHandOnEnter => 1,
    maxTalkers => 3,
    inSessionInvitation => 1,
    boundaryMinutes => 15,
    fullPermissions => 1,
    supervised => 1,
    seats => 2,
    restrictedMeeting => 1,
);

my $elm3_params = $class->_freeze( \%insert_data );
# some spot checks on freezing
is($elm3_params->{start}, $session_start, 'frozen "start"');
is($elm3_params->{boundaryTime}, 15, 'frozen "boundaryMinutes"');
is($elm3_params->{facilitator}, 'user_tba', 'frozen facilitator');
is($elm3_params->{private}, 'true', 'frozen "privateMeeting"');
is($elm3_params->{reservedSeatCount}, 2, 'frozen "seats"');
is($elm3_params->{restrictParticipants}, 'true', 'frozen "restrictedMeeting"');

SKIP: {

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    my $connection_class = $result{class};
    skip ($result{reason} || 'skipping live tests', 46)
	if $connection_class->isa('t::Elive::MockConnection');

    $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    $insert_data{facilitatorId} = Elive->login->userId,
    my %update_data = (
	costCenter => 'testing again',
	boundaryMinutes => 30,
	);

    my $session_id;

    do {
	my $preload = _create_preload();
	$insert_data{preloadIds} = [$preload];

	my $session = $class->insert(\%insert_data);

	isa_ok($session, $class, 'session');

	foreach (sort keys %insert_data) {
	    next if $_ =~ m{preload|password};
	    is( $session->$_, $insert_data{$_}, "insert: $_ saved");
	}

	my $preloads = $session->list_preloads;
	is_deeply($preloads, [$preload], 'preloads after insert');

	my $preload2 = _create_preload();
	$update_data{preloadIds} = [$preload2];

	lives_ok( sub{$session->update( \%update_data )}, 'session update - lives' );

	$preloads = undef;
	$preloads = $session->list_preloads;
	is_deeply($preloads, [$preload, $preload2], 'preloads after update');

	my %props;
	@props{ keys %insert_data, keys %update_data } = undef;

	foreach (sort keys %props) {
	    next if $_ =~ m{preload|password};

	    my $expected_value = (exists $update_data{$_}
				  ? $update_data{$_}
				  : $insert_data{$_});

	    is( $session->$_, $expected_value, "update: $_ saved");
	}

	do {
	    my $sessionJNLP;
	    lives_ok(sub {$sessionJNLP = $session->buildJNLP(
			      version => '8.0',
			      displayName => 'Elive Test',
			      )},
		     '$session->buildJNLP - lives');

	    ok($sessionJNLP && !ref($sessionJNLP), 'got session JNLP');
	    lives_ok(sub {XMLin($sessionJNLP)}, 'session JNLP is valid XML (XHTML)');
	};
	
	ok($session->web_url, 'got session web_url()');

	lives_ok( sub{$session->update()}, 'ineffective session update - lives' );
	$preload->delete;
	$preload2->delete;

	$session_id = $session->id;
    };

    # drop out of scope to impicitly cull objects and clear object cache

    do {

	my %update_data = (
	    costCenter => 'testing yet again!',
	    boundaryMinutes => 45,
	    );

	my $session = Elive::Entity::Session->retrieve($session_id);

	#
	# also try a different variation of update. set properties before-hand,
	# then do a parameterless update
	#
	foreach (sort keys %update_data) {
	    $session->$_( $update_data{$_} );
	}

	$session->update;

	is($session->name, $insert_data{name}, 'session value unchanged (name)');

	foreach (sort keys %update_data) {
	    is($session->$_, $update_data{$_}, "session value updated ($_)");
	}

	$session->delete;
    };
}

########################################################################

sub _create_preload {
    Elive::Entity::Preload->upload({
	type => 'whiteboard',
	name => 'test.wbd',
	ownerId => Elive->login,
	data => 'junk dsadksadkl a dfflkdsfnmsdfsd xddsfhsfsdfxssl sd',
    });
}

Elive->disconnect;

