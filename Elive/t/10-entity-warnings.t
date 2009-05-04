#!perl -T
use warnings; use strict;
use Test::More tests => 6;
use Test::Warn;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::User' );
}

Elive->connection(Elive::Connection->connect('http://test.org'));

warning_like (\&do_unsaved_update,
	      qr{destroyed without saving .* changes},
	      'unsaved change gives warning'
    );

warnings_like(
    \&construct_unknown_property,
    qr{unknown property},
    'constructing unknown property gives warning',
    );

exit(0);

########################################################################

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

sub construct_unknown_property {
    Elive::Entity::User->construct
	({  userId => 1234,
	    loginName => 'user',
	    loginPassword => 'pass',
	    junk => 'abc',
	 });
}

