#!perl
use warnings; use strict;
use Test::More tests => 10;
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

    my %result = t::Elive->auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	8)
	unless $auth && @$auth;

    Elive->connect(@$auth);

    my $login = Elive->login;

    #
    # just retest some of our entity management in a live
    # production environment
    #

    ok(!$login->is_changed, 'login not yet changed');

    my $loginName_old = $login->loginName;
	
    my $loginName_new = $loginName_old.'x';
    $login->loginName($loginName_new);

    ok($login->loginName eq $loginName_new, 'login name changed enacted');
    ok($login->is_changed, 'login object showing as changed');

    my $login_refetch;

    lives_ok(
	     sub {$login_refetch = Elive::Entity::User->retrieve([$login->userId], reuse => 1)},
	     're-retrieve of updated object with reuse - lives');

    ok(Scalar::Util::refaddr($login_refetch) == Scalar::Util::refaddr($login_refetch),
       "login objects unified");

    ok($login->loginName eq $loginName_new,
       '"reuse => 1" option repected on retrieve');

    ok($login->is_changed, 'login object still showing as changed');

    dies_ok(
	     sub {$login_refetch = Elive::Entity::User->retrieve([$login->userId], reuse => 0)},
	     're-retrieve of updated object without reuse - dies');

    $login->revert;

}

Elive->disconnect;

