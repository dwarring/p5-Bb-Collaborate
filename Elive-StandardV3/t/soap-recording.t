#!perl -T
use warnings; use strict;
use Test::More tests => 6;
use Test::Fatal;

use lib '.';
use t::Elive::StandardV3;

use Elive::StandardV3;
use Elive::StandardV3::Recording;
use Elive::StandardV3::Session;

SKIP: {

    my %result = t::Elive::StandardV3->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 6)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive::StandardV3->connection($connection);

    my $end_time = time();
    my $start_time = $end_time  -  60 * 60 * 24 * 7; # one week approx
    my $recordings;

    is( exception {
	$recordings = Elive::StandardV3::Recording->list(filter => {startTime => $start_time, endTime => $end_time})
	  } => undef,
	'list recordings - lives');

    die "unable to get recordings"
	unless $recordings;

    skip('Unable to find any existing recordings to test', 5)
	unless @$recordings;

    my $recording = $recordings->[-1];

    # this recording is not under our control, so don't assume too much
    # and just test a few essential properties

    ok($recording->recordingId, "recording has recordingId")
	or die "unable to continue without a recording id";
    note("working with recording: ".$recording->recordingId);

    ok($recording->recordingSize, "recording has recordingSize");

    my $recording_url;
    is (exception {$recording_url = $recording->recording_url} => undef,
	'$recording->recording_url - lives');
    ok($recording_url, "got recording_url");
    note("recording url is: $recording_url");

    # try to find a session with associated recording(s)

    my ($session) = List::Util::first {$_->recordings} @{ Elive::StandardV3::Session->list() };

    if ($session) {

	note "found session with recordings: ".$session->sessionId;

	my $session_recordings = $session->list_recordings;
	ok($session_recordings && $session_recordings->[0], '$session->list_recordings')
	    or diag("unable to find the purported recordings for session: ".$session->sessionId);
    }
    else {
	Test::More->builder->skip("unable to find a session with recordings");
    }
}

Elive::StandardV3->disconnect;

