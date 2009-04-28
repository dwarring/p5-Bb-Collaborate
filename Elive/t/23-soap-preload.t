#!perl
use warnings; use strict;
use Test::More tests => 17;
use Test::Exception;

package main;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Preload' );
};

my $class = 'Elive::Entity::Preload' ;

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+';
$data[1] = join('',map {pack('C', $_)} (0..255));

for (0..1) {
    ok($class->_hex_decode($class->_hex_encode($data[$_])) eq $data[$_], "encode/decode $_");   
}

SKIP: {

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	13)
	unless $auth;

    Elive->connect(@$auth);

    my $preload = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test.wbd',
	ownerId => Elive->login->userId,
	data => $data[0],
    },
    );

    isa_ok($preload, $class, 'preload object');

    ok($preload->type eq 'whiteboard', "preload type is 'whiteboard'");
    ok($preload->mimeType eq 'application/octet-stream','expected value for mimeType (guessed)');
    ok($preload->name eq 'test.wbd','expected name');
    ok($preload->ownerId == Elive->login->userId, 'expected user id');

    my $data_download = $preload->download;

    ok($data_download, 'got data download');
    ok($data_download eq $data[0], 'download matches upload');

    ok (my $preload_id = $preload->preloadId, 'got preload id');

    $preload = undef;

    ok($preload = Elive::Entity::Preload->retrieve([$preload_id]), 'preload retrieval');

    lives_ok(sub {$preload->delete}, 'preload deletion - lives');

    dies_ok(sub {$preload->retrieve([$preload_id])}, 'attempted retrieval of deleted preload - dies');

    my $preload2 = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test.wav',
	ownerId => Elive->login->userId,
	data => $data[1],
    },
    );

    ok($preload2->mimeType eq 'audio/x-wav','expected value for mimeType (guessed)');

    my $preload3 = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test_no_ext',
	ownerId => Elive->login->userId,
	mimeType => 'video/mpeg',
	data => $data[1],
    },
    );

    ok($preload3->mimeType eq 'video/mpeg','expected value for mimeType (set)');

    $preload2->delete;
    $preload3->delete;

}

Elive->disconnect;

