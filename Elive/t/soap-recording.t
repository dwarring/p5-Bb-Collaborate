#!perl
use warnings; use strict;
use Test::Builder;
use Test::More tests => 18;
use Test::Exception;

use lib '.';
use t::Elive;

use Elive;
use Elive::Connection;
use Elive::Entity::Recording;
use Elive::Entity::Meeting;
use XML::Simple;

my $class = 'Elive::Entity::Recording';

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+. This is unplayable junk!';
$data[1] = join('',map {pack('C', $_)} (0..255));

########################################################################
##   ** Mock tests **
########################################################################

do {
    my %result = t::Elive->test_connection(only => 'mock');
    my $auth = $result{auth};

    my $connection_class = $result{class};
    my $mock_connection = $connection_class->connect(@$auth);
    Elive->connection($mock_connection);
    my $now = time();

    my $meeting = Elive::Entity::Meeting->insert({
	name => 'created by t/soap-recording.t',
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
	roomName => 'room t/soap-recording.t',
	creationDate => $now.'000',
	open => 1,
    },
    );
    isa_ok($recording, 'Elive::Entity::Recording');

    Elive->disconnect;
};

########################################################################
##   ** Live tests **
########################################################################

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 16)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $recording_id = time()."000_$$".sprintf("%4d", rand(9999));
    my $room_name = 'generated by soap_recording.t (unplayable!)';

    diag "uploading recording: $recording_id";
    my $recording;

    lives_ok( sub {
	$recording = Elive::Entity::Recording->upload(
	    {
		recordingId =>  $recording_id,
		roomName => $room_name,
		version => Elive->server_details->version,
		data => $data[0],
		size => length($data[0]),
	    },
	    )
		 },
		 "upload recording - lives",
	);

    isa_ok($recording, $class, 'uploaded recording');
    is($recording->recordingId, $recording_id, 'uploaded recording id as expected');
    is($recording->roomName, $room_name,'uploaded recording name as expected');

    my $recordings = Elive::Entity::Recording->list;

    ok($recordings && @$recordings, 'got list of recordings');

    ok(do{grep {$_->recordingId eq $recording_id} @$recordings},
       'uploaded recording found in recordings');

    my $data_download = $recording->download;

    ok($data_download, 'got recording download');
    ok(length($data_download) == length($data[0]),
       sprintf('download has expected size %d bytes', length($data[0])),
	);

    is($data_download, $data[0], 'downloaded data matches upload');

    my $recordingJNLP;

    lives_ok(sub {
	$recordingJNLP = $recording->buildJNLP(
	    userId => Elive->login->userId,
	    userIP => '192.168.0.1',
	    )},
	     "buildJNLP - lives",
	);

    ok($recordingJNLP && !ref($recordingJNLP), 'got recording JNLP');
    lives_ok(sub {XMLin($recordingJNLP)}, 'JNLP is valid XML (XHTML)');
    ok(my $web_url = $recording->web_url, 'got recording web_url()');
		
    $recording = undef;

    ok($recording = Elive::Entity::Recording->retrieve([$recording_id]), 'recording retrieval');

    lives_ok(sub {$recording->delete}, 'recording delete - lives');

    dies_ok(sub {Elive::Entity::Recording->retrieve([$recording_id])}, "retrieval after delete as expected");

}

Elive->disconnect;

