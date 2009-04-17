#!perl -T
use warnings; use strict;
use Test::More tests => 12;
use Test::Exception;

package main;

BEGIN {
	use_ok( 'Elive' );
	use_ok( 'Elive::Connection' );
	use_ok( 'Elive::Entity::User' );
}

Elive->connection(Elive::Connection->new('http://test.org'));

dies_ok(
    sub {
	Elive::Entity::User->construct
	    ({	loginName => 'user',
		loginPassword => 'pass'})},
##    "can't construct Elive::Entity::User without value for primary key field: userId",
    "construct without primary key - dies"
    );

my %user_data =  (
    userId => 1234,
    loginName => 'bbill',
    loginPassword => 'pass'
    );

my $user_data;

lives_ok(
    sub {
	$user_data = Elive::Entity::User->construct(\%user_data)
    },
    "initial construction - lives"
    );

unless ($user_data) {
    diag "dont' have user object - unable to continue testing";
    exit(1);
}

$user_data->loginName( $user_data->loginName .'x' );

dies_ok(
    sub {Elive::Entity::User->construct(\%user_data)},
    "reconstructing unsaved object - dies"
    );

$user_data->revert;

lives_ok(
    sub {Elive::Entity::User->construct(\%user_data)},
    "construction after reverting changes - lives"
    );

lives_ok(
    sub {$user_data->set('email', 'bbill@test.org')},
    "setter on non-key value - lives"
    );

dies_ok(
    sub {$user_data->set('userId', undef)},
    "clearing primary key field - dies"
    );

dies_ok(
    sub {$user_data->set('userId', $user_data->userId.'9')},
    "updating primary key field - dies"
    );

lives_ok(
    sub {$user_data->set('userId', $user_data->userId)},
    "ineffective primary key update - lives"
    );

dies_ok(
    sub {$user_data->set('noSuchField', 'die you ^&*#@')},
    "setter on unknown field - dies"
    );

$user_data->revert;
