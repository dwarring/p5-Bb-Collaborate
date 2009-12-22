#!perl
use warnings; use strict;
use Test::Builder;
use Test::More tests => 13;
use Test::Exception;

use lib '.';
use t::Elive;

BEGIN {
    use_ok('Elive');
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Recording' );
    use_ok( 'Elive::Entity::Meeting' );
};

my $class = 'Elive::Entity::Recording';

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+';
$data[1] = join('',map {pack('C', $_)} (0..255));

do {
    my %result = t::Elive->test_connection(only => 'mock');
    my $auth = $result{auth};

    my $connection_class = $result{class};
    my $mock_connection = $connection_class->connect(@$auth);
    Elive->connection($mock_connection);
    my $now = time();

    my $meeting = Elive::Entity::Meeting->insert({
	name => 'created by t/24-soap-recording.t',
	facilitatorId => Elive->login->userId,
	start => $now . '000',
	end => ($now+900) . '000',
	privateMeeting => 1,
    });
    isa_ok($meeting, 'Elive::Entity::Meeting');

    my $recording = Elive::Entity::Recording->insert(
    {
	facilitator => Elive->login->userId,
	meetingId => $meeting->meetingId,
##	fileName => '/tmp/recording.out',
	data => $data[0],
	size => length($data[0]),
	version => Elive->server_details->version,
	roomName => 'room t/24-soap-recording.t',
	creationDate => $now.'000',
	open => 1,
    },
    );
    isa_ok($recording, 'Elive::Entity::Recording');

##    my $recording =  Elive::Entity::Recording->import_from_server
##	({fileName => '/dev/null',
##	  version => Elive->server_details->version,
##	  meetingId => $meeting->meetingId,
##	 });

    Elive->disconnect;
};

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skiiping live tests',
	7)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $recordings = Elive::Entity::Recording->list;

    my $smallest_recording;

    foreach (@$recordings) {
	my $size = $_->size
	    or next;

	$smallest_recording = $_
	    if (!defined $smallest_recording
		|| $size < $smallest_recording->size);
    }

    skip('No suitable recordings found on this server', 7)
	unless ($smallest_recording);

    my $recording = $smallest_recording;

    isa_ok($recording, $class, 'recording object');

    ok (my $recording_id = $recording->recordingId, 'got recording id');

    diag sprintf ("analyzing recording %s: %s (%0.1f kb)", $recording->recordingId, $recording->roomName, $recording->size/1000);

##    ok($recording->name eq 'room 24-soap-recording.','expected name');
##    ok($recording->facilitator == Elive->login->userId, 'expected user id');

    if ($recording->size >= 1_000_000) {
	my $t = Test::Builder->new;
	$t->skip(sprintf("skipping download test 1. excessive size of %0.1fmb",
		      $recording->size / 1_000_000));
	$t->skip('skipping download test 2');
    }
    else {
	my $data_download = $recording->download;

	ok($data_download, 'got recording download');
	ok(length($data_download) == $recording->size,
	   sprintf('download has expected size %0.1f kb', $recording->size/1_000));
    }

    my $recordingJNLP;

    lives_ok(sub {
	$recordingJNLP = $recording->buildJNLP(
	    userId => Elive->login->userId,
	    userIP => '192.168.0.1',
	    )},
	     "buildJNLP - lives",
	);

    ok($recordingJNLP && !ref($recordingJNLP), 'got recording JNLP');
		
    $recording = undef;

    ok($recording = Elive::Entity::Recording->retrieve([$recording_id]), 'recording retrieval');

##    $meeting->delete;

##    lives_ok(sub {$recording->delete}, 'recording deletion - lives');

##    dies_ok(sub {$recording->retrieve([$recording_id])}, 'attempted retrieval of deleted recording - dies');
}

Elive->disconnect;

