#!perl
use warnings; use strict;
use Test::More tests => 12;
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
	8)
	unless $auth;

    Elive->connect(@$auth);

    my $preload = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	mimeType => 'application/octet-stream',
	name => 'test.wbd',
	ownerId => Elive->login->userId,
	data => $data[0],
    },
    );

    isa_ok($preload, $class, 'preload object');

    ok($preload->type eq 'whiteboard', "preload type is 'whiteboard'");
    ok($preload->mimeType eq 'application/octet-stream','expected value for mimeType');
    ok($preload->name eq 'test.wbd','expected name');
    ok($preload->ownerId == Elive->login->userId, 'expected user id');

    my $data_download = $preload->download;

    ok($data_download, 'got data download');
    ok($data_download eq $data[0], 'download matches upload');

    lives_ok(sub {$preload->delete},'preload deletion');
}

Elive->disconnect;

