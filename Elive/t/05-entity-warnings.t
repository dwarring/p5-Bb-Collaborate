#!perl -T
use warnings; use strict;
use Test::More tests => 5;
use Test::Warn;

package Elive::Connection::TestStub;

sub url {return 'http://elive.test.org/test'};

########################################################################

package main;

BEGIN {
	use_ok( 'Elive' );
	use_ok( 'Elive::Entity' );
	use_ok( 'Elive::Entity::User' );
}

my $connection_stub = bless {}, 'Elive::Connection::TestStub';

Elive->_last_connection($connection_stub);

warning_like (\&do_unsaved_update,
	      qr{destroyed without saving changes},
	      'unsaved change gives warning'
    );

sub do_unsaved_update {

    my $user = Elive::Entity::User->construct
	({
	    userId => 123456,
	    loginName => 'some_user',
	    loginPassword => 'some_pass',
         },
	);

    $user->loginName($user->loginName . 'x');
    $user = undef;
}

warnings_like(
    sub {
	Elive::Entity::User->construct
	    ({  userId => 1234,
		loginName => 'user',
		loginPassword => 'pass',
		junk => 'abc',
	     })},
    qr{unknown property},
    );

