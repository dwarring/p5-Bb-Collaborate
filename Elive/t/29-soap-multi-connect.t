#!perl
use warnings; use strict;
use Test::More tests => 23;
use Test::Exception;

use lib '.';
use t::Elive;

#
# Some rough tests that we can handle multiple connections.
# Look for evidence of 'crossed wires'. e.g. in the cache, entity
# updates or comparison functions.
# 

use Elive;
use Elive::Connection;
use Elive::Entity::Preload;

my $class = 'Elive::Entity::Preload' ;

SKIP: {

    my $Skip = 23;

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    my %result_2 = t::Elive->test_connection(suffix => '_2');
    my $auth_2 = $result_2{auth};

    skip('$ELIVE_TEST_URL and ELIVE_TEST_URL_2 are the same!',
	 $Skip)
	if ($auth->[0] eq $auth_2->[0]);

    skip('$ELIVE_TEST_USER and ELIVE_TEST_USER_2 are the same!',
	 $Skip)
	if ($auth->[1] eq $auth_2->[1]);

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);

    ok($connection, 'got first connection');
    isa_ok($connection, 'Elive::Connection','connection')
	or exit(1);

    my $connection_class_2 = $result_2{class};
    my $connection_2 = $connection_class_2->connect(@$auth_2);

    ok($connection_2, 'got second connection');
    isa_ok($connection_2, 'Elive::Connection','connection')
	or exit(1);

    ok($connection->url ne $connection_2->url, 'connections have distinct urls');
    ok(my $user = $connection->login, 'connection login');
    isa_ok($user, 'Elive::Entity::User','login');

    ok(my $user_2 = $connection_2->login, 'connection_2 login');
    isa_ok($user_2, 'Elive::Entity::User','login_2');

    ok(Scalar::Util::refaddr($user) != Scalar::Util::refaddr($user_2),
	'users are distinct objects');

    is_deeply($user->connection, $connection, 'first entity/connection association');
    is_deeply($user_2->connection, $connection_2, 'second entity/connection association');

    #
    # LDAP login names may be case insensitive
    #
    ok(uc($user->loginName) eq uc($auth->[1]), 'login name for first connection as expected');
    ok(uc($user_2->loginName) eq uc($auth_2->[1]), 'login name for second connection as expected');

    ok(my $server_details = $connection->server_details, 'can get connection login');
    isa_ok($server_details, 'Elive::Entity::ServerDetails','server_details');

    ok(!$user->is_changed, 'login not yet changed');

    my $userName_old = $user->loginName;
	
    my $userName_new = $userName_old.'x';
    $user->loginName($userName_new);

    ok($user->loginName eq $userName_new, 'login name changed enacted');
    ok($user->is_changed, 'user object showing as changed');

    ok(!$user_2->is_changed, 'user on second connection - not affected');

    $user->revert;
    ok(!$user->is_changed, 'user revert');

    lives_ok(sub {$connection->disconnect},
	     'disconnect first connection - lives');

    lives_ok(sub {$connection_2->disconnect},
	     'disconnect second connection - lives');
    
}

