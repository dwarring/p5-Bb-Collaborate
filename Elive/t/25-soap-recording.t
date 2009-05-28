#!perl
use warnings; use strict;
use Test::More tests => 4;
use Test::Exception;

package main;

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

SKIP: {

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	0)
	unless $auth;

    Elive->connect(@$auth);

##
## ** STUB  ** STUB  ** STUB  ** STUB  ** STUB  ** STUB  ** STUB  ** STUB 

##    ok(my $meeting = Elive::Entity::Meeting->insert({
##	name => 'created by t/24-soap-recording.t',
##	facilitatorId => Elive->login->userId,
##	start => time() . '000',
##	end => (time()+900) . '000',
##	privateMeeting => 1,
##    }));

##    my $recording = Elive::Entity::Recording->insert(
##    {
##	facilitator => Elive->login->userId,
##	meetingId => $meeting->meetingId,
##	fileName => '/tmp/recording.out',
##	data => $data[0],
##	size => length($data[0]),
##	version => Elive->server_details->version,
##	roomName => 'room t/24-soap-recording.t',
##	open => 1,
##    },
##    );

##    my $recording =  Elive::Entity::Recording->import_from_server
##	({fileName => '/dev/null',
##	  version => Elive->server_details->version,
##	  meetingId => $meeting->meetingId,
##	 });

##    isa_ok($recording, $class, 'recording object');

##    ok($recording->name eq 'room 24-soap-recording.','expected name');
##    ok($recording->facilitator == Elive->login->userId, 'expected user id');

##    my $data_download = $recording->download;
##
##    ok($data_download, 'got data download');
##    ok($data_download eq $data[0], 'download matches upload');

##    ok (my $recording_id = $recording->recordingId, 'got recording id');

##    $recording = undef;

##    ok($recording = Elive::Entity::Recording->retrieve([$recording_id]), 'recording retrieval');

##    $meeting->delete;

##    lives_ok(sub {$recording->delete}, 'recording deletion - lives');

##    dies_ok(sub {$recording->retrieve([$recording_id])}, 'attempted retrieval of deleted recording - dies');

}

Elive->disconnect;

