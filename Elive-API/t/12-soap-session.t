#!perl
use warnings; use strict;
use Test::More tests => 21;
use Test::Exception;
use Test::Builder;
use version;

use lib '.';
use t::Elive::API;

use Elive::API::Session;

our $t = Test::Builder->new;
our $class = 'Elive::API::Session' ;

our $connection;

SKIP: {

    my $skippable = 21;

    eval 'require DateTime';
    skip('DateTime is required to run this test', $skippable)
	if $@;

    my %result = t::Elive::API->test_connection();
    my $auth = $result{auth};

   skip ($result{reason} || 'skipping live tests', $skippable)
	unless $auth && @$auth;

    use Elive::Connection::API;
    my $connection_class = $result{class};
    $connection = $connection_class->connect(@$auth);
    Elive::API->connection($connection);

    my $dt = DateTime->now->truncate(to => 'minute');

    do {
	#
	# generate a date that's on the quarter hour and slightly into
	# the future (to allow for connection latency).
	#
	$dt->add(minutes => 1);
    } until ($dt->minute % 15 == 0 && $dt->epoch > time() + 60);

    my $session_start = $dt->epoch;
    my $session_end = $session_start + 900;

    $session_start .= '000';
    $session_end .= '000';

    my %insert_data = (
	sessionName => 'test session, generated by t/12-soap-session.t',
	creatorId => $connection->user,
	startTime =>  $session_start,
	endTime => $session_end,
	openChair => 1,
	mustBeSupervised => 0,
	permissionsOn => 1,
	groupingList => [qw(mechanics sewing)],
    );

    my ($session) = $class->insert(\%insert_data);

    isa_ok($session, $class, 'session');
    ok(my $session_id = $session->sessionId, 'Insert returned session id');

    diag "session-id: $session_id";

    foreach (keys %insert_data) {
	#
	# returned record doesn't contain password
	is_deeply($session->$_, $insert_data{$_}, "session $_ as expected");
    }

    my %update_data = (
	chairNotes => 'test moderator notes. Here are some entities: & > <',
	nonChairNotes => 'test user notes; some more entities: &gt;',
	raiseHandOnEnter => 1,
	maxTalkers => 3,
	recordingModeType => 2,
	);

    $session->update(\%update_data);

    $session = undef;

    ok ($session = Elive::API::Session->retrieve([$session_id]),
	'Refetch of session');

    foreach (keys %update_data) {
	#
	# returned record doesn't contain password
	is($session->$_, $update_data{$_}, "session update $_ as expected");
    }

    my $session_url;
    lives_ok(sub {$session_url = $session->session_url(user_id => 'bob', display_name => 'Robert')}, 'Can generate session Url for some user');
    diag "session url: $session_url";

    my $attendances;

    dies_ok(sub {$attendances = $session->attendance('')}, 'session attendance sans date - dies');

    my $today_hires = DateTime->today->epoch.'000';
    lives_ok(sub {$attendances = $session->attendance($today_hires)}, 'session attendance with date - lives');

    lives_ok(sub {$session->delete},'session deletion - lives');

    my $deleted_session;
    eval {$deleted_session = Elive::API::Session->retrieve([$session_id])};

    ok($@ || !$deleted_session, "can't retrieve deleted session");
}

Elive->disconnect;

