#!perl
use warnings; use strict;
use Test::More tests => 19;
use Test::Exception;

package main;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Preload' );
};

my $class = 'Elive::Entity::Preload' ;

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+';
$data[1] = join('',map {pack('C', $_)} (0..255));

SKIP: {

    my $Skip = 16;

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	$Skip)
	unless $auth && @$auth;

    my %result_2 = Elive->_get_test_auth(suffix => '_2');
    my $auth_2 = $result_2{auth};

    skip ($result_2{reason} || 'unable to find secondary test connection',
	$Skip)
	unless $auth_2 && @$auth_2;

    skip('$ELIVE_TEST_URL and ELIVE_TEST_URL_2 are the same!',
	 $Skip)
	if ($auth->[0] eq $auth_2->[0]);

    skip('$ELIVE_TEST_USER and ELIVE_TEST_USER_2 are the same!',
	 $Skip)
	if ($auth->[1] eq $auth_2->[1]);

    diag ("connecting: user=$auth->[1], url=$auth->[0]");

    my $connection = Elive::Connection->connect(@$auth);

    ok($connection, 'got first connection');
    isa_ok($connection, 'Elive::Connection','connection')
	or exit(1);

    diag ("connecting: user=$auth_2->[1], url=$auth_2->[0]");

    my $connection_2 = Elive::Connection->connect(@$auth_2);

    ok($connection_2, 'got second connection');
    isa_ok($connection_2, 'Elive::Connection','connection')
	or exit(1);

    ok($connection->url ne $connection_2->url, 'Connections have distinct urls');
    use Carp; $SIG{__DIE__} = \&Carp::confess;
    ok(my $user = $connection->login, 'connection login');
    isa_ok($user, 'Elive::Entity::User','login');

    ok(my $user_2 = $connection_2->login, 'connection_2 login');
    isa_ok($user_2, 'Elive::Entity::User','login_2');

    ok(Scalar::Util::refaddr($user) != Scalar::Util::refaddr($user_2),
	'users are distinct objects');

    ok($user->loginName eq $auth->[1], 'login name for first connection as expected');
    ok($user_2->loginName eq $auth_2->[1], 'login name for second connection as expected');

    ok(my $server_details = $connection->server_details, 'can get connection login');
    isa_ok($server_details, 'Elive::Entity::ServerDetails','server_details');

    lives_ok(sub {$connection->disconnect},
	     'disconnect 1 - lives');

    lives_ok(sub {$connection_2->disconnect},
	     'disconnect 2 - lives');
    
}

Elive->disconnect;

