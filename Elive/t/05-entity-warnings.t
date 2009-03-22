#!perl -T
use warnings; use strict;
use Test::More tests => 6;
use Test::Warn;

BEGIN {
    use_ok( 'Data::Class::Repository' );
    use_ok( 'Elive' );
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::User' );
}

Elive->connection(Data::Class::Repository->new('http://test.org'));

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

