#!perl -T
use warnings; use strict;
use Test::More tests => 5;
use Test::Fatal;

use lib '.';
use t::Elive::StandardV3;

use Elive::StandardV3;
use Elive::StandardV3::Recording;

SKIP: {

    use Carp; $SIG{__DIE__} = \&Carp::confess;
    my %result = t::Elive::StandardV3->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 5)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive::StandardV3->connection($connection);

    my $recordings;

    $recordings = Elive::StandardV3::Recording->list;

    is( exception {
	$recordings = Elive::StandardV3::Recording->list
	  } => undef,
	'list recordings - lives');

    die "unable to get recordings"
	unless $recordings;

    skip('Unable to find any existing recordings to test', 4)
	unless @$recordings;

    my $recording = $recordings->[-1];

    # this recording is not under our control, so do'nt assume too much
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
}

Elive::StandardV3->disconnect;

