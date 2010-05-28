#!perl
use warnings; use strict;
use Test::More tests => 21;
use Test::Exception;
use Scalar::Util;

use lib '.';
use t::Elive;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Entity::User' );
};

my $class = 'Elive::Entity::User' ;

SKIP: {

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	19)
	unless $auth && @$auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $login = Elive->login;
    ok(Scalar::Util::blessed($login), 'Elive->login returns an object');

    #
    # just retest some of our entity management with active live or mock
    # connections.
    #

    ok(!$login->is_changed, 'login not yet changed');

    my $loginName_old = $login->loginName;
	
    my $loginName_new = $loginName_old.'x';
    $login->loginName($loginName_new);

    ok($login->loginName eq $loginName_new, 'login name changed enacted');
    ok($login->is_changed, 'login object showing as changed');

    my $login_refetch;

    #
    # check the retrieve -reuse option
    #

    lives_ok(
	     sub {$login_refetch = Elive::Entity::User->retrieve([$login->userId], reuse => 1)},
	     're-retrieve of updated object with reuse - lives');

    ok(Scalar::Util::refaddr($login_refetch) == Scalar::Util::refaddr($login_refetch),
       "login objects unified to cache");

    ok($login->is_changed, 'login object still showing as changed');

    dies_ok(
	     sub {$login_refetch = Elive::Entity::User->retrieve([$login->userId], reuse => 0)},
	     're-retrieve of updated object without reuse - dies');

    #
    # check the retrieve -raw option
    #
    my $login_raw_data;

    lives_ok(
	     sub {$login_raw_data = Elive::Entity::User->retrieve([$login->userId], raw => 1)},
	     're-retrieve of updated object with reuse - lives');

    ok(!Scalar::Util::blessed($login_raw_data), 'raw retrieval returns unblessed data');
    
    ok($login_raw_data->{loginName} eq $loginName_old,
       'raw retrieval bypasses cache');

    ok($login->loginName eq $loginName_new,
       'changes held in cache');

    $login->revert;

    ok($login->loginName eq $loginName_old,
       'revert of login user');

    #
    # check refetch, both on object and primary key
    #
    my $user_id = $login->userId;
    my $user_refetched;

    lives_ok(sub {$user_refetched = Elive::Entity::User->retrieve([$login])}, 'refetch by object - lives');
    isa_ok($user_refetched,'Elive::Entity::User', 'user refetched by object');
    ok($user_refetched->userId eq $user_id, "user refetch by object, as expected");

    lives_ok(sub {$user_refetched = Elive::Entity::User->retrieve([$user_id])}, 'refetch by id - lives');
    isa_ok($user_refetched,'Elive::Entity::User', 'user refetched by primary key');
    ok($user_refetched->userId eq $user_id, "user refetch by id, as expected");
}

Elive->disconnect;

