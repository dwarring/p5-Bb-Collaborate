#!perl
use warnings; use strict;
use Test::More tests => 34;
use Test::Exception;

package main;

BEGIN {
    use_ok('Elive');
    use_ok( 'Elive::Entity::Preload' );
    use_ok( 'Elive::Entity::Meeting' );
    use_ok ('Elive::Util');
};

my $class = 'Elive::Entity::Preload' ;

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+';
$data[1] = join('',map {pack('C', $_)} (0..255));

for (0..1) {
    #
    # belongs in util tests
    ok(Elive::Util::_hex_decode(Elive::Util::_hex_encode($data[$_])) eq $data[$_], "encode/decode $_");   
}

SKIP: {

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	28)
	unless $auth;

    Elive->connect(@$auth);

    my @preloads;

    $preloads[0] = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test.wbd',
	ownerId => Elive->login->userId,
	data => $data[0],
    },
    );

    isa_ok($preloads[0], $class, 'preload object');

    ok($preloads[0]->type eq 'whiteboard', "preload type is 'whiteboard'");
    ok($preloads[0]->mimeType eq 'application/octet-stream','expected value for mimeType (guessed)');
    ok($preloads[0]->name eq 'test.wbd','expected name');
    ok($preloads[0]->ownerId eq Elive->login->userId, 'expected user id');

    my $data_download = $preloads[0]->download;

    ok($data_download, 'got data download');
    ok($data_download eq $data[0], 'download matches upload');

    ok (my $preload_id = $preloads[0]->preloadId, 'got preload id');

    $preloads[0] = undef;

    ok($preloads[0] = Elive::Entity::Preload->retrieve([$preload_id]), 'preload retrieval');

    ok(my $meeting = Elive::Entity::Meeting->insert({
	name => 'created by t/23-soap-preload.t',
	facilitatorId => Elive->login->userId,
	start => time() . '000',
	end => (time()+900) . '000',
	privateMeeting => 1,
    }),
	'inserted meeting');

    $preloads[1] = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test.wav',
	ownerId => Elive->login->userId,
	data => $data[1],
    },
    );

    ok($preloads[1]->mimeType eq 'audio/x-wav','expected value for mimeType (guessed)');

    $preloads[2] = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test_no_ext',
	ownerId => Elive->login->userId,
	mimeType => 'video/mpeg',
	data => $data[1],
    },
    );

    ok($preloads[2]->mimeType eq 'video/mpeg','expected value for mimeType (set)');

    my $check;

    lives_ok(sub {$check = $meeting->check_preload($preloads[0])},
	     'meeting->check_preloads - lives');

    ok(!$check, 'check_meeting prior to add - returns false');

    lives_ok(sub {$meeting->add_preload($_) for (@preloads)},
	     'adding meeting preloads - lives');

    lives_ok(sub {$check = $meeting->check_preload($preloads[0])},
	     'meeting->check_preloads - lives');

    ok($check, 'check_meeting after add - returns true');

    my $preloads_list;
    lives_ok(sub {$preloads_list = $meeting->list_preloads},
	     'list_meeting_preloads - lives');

    isa_ok($preloads_list, 'ARRAY', 'preloads list');

    ok(@$preloads_list == 3, 'meeting has three preloads');

    do {
	my @preload_ids = map {$_->preloadId} @preloads;
	my $n = 0;

	foreach (@$preloads_list) {
	    isa_ok($_, 'Elive::Entity::Preload', "preload_list[$n]");
	    my $preload_id = $_->preloadId;
	    ok((grep {$_ eq $preload_id} @preload_ids), "preload_id[$n] - as expected");
	    ++$n;
	    
	}
    };

       # start to tidy up

    $meeting->delete;

    lives_ok(sub {$preloads[0]->delete}, 'preloads[0] deletion - lives');

    dies_ok(sub {$preloads[0]->retrieve([$preload_id])}, 'attempted retrieval of deleted preload - dies');

    $preloads[1]->delete;
    $preloads[2]->delete;

}

Elive->disconnect;

