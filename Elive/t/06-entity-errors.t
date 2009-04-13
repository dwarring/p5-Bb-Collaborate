#!perl -T
use warnings; use strict;
use Test::More tests => 7;
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
    loginName => 'user',
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


