#!perl
use warnings; use strict;
use Test::More tests => 10;
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

SKIP: {

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	8)
	unless $auth && @$auth;

    Elive->connect(@$auth);

    ok(my $connection = Elive->connection, 'got connection');
    isa_ok($connection, 'Elive::Connection','connection')
	or exit(1);

    my $login;

    ok ($login = Elive->login, 'got login');
    isa_ok($login, 'Elive::Entity::User','login');
    ok($login->loginName eq $auth->[1], 'username matches login');

    my $server_details;
    my $server_version;

    ok ($server_details = Elive->server_details, 'got server details');
    isa_ok($server_details, 'Elive::Entity::ServerDetails','server_details');
    ok($server_version = $server_details->version, 'got server version');
    diag ("testing server: $auth->[1], url: $auth->[0], version: $server_version");

}

Elive->disconnect;

