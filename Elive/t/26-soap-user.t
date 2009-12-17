#!perl
use warnings; use strict;
use Test::More tests => 9;
use Test::Exception;

use lib '.';
use t::Elive;

my $class = 'Elive::Entity::User' ;


use Carp;
$SIG{__DIE__} = \&Carp::confess;

SKIP: {
    #
    # restrict our user tests to the mock database. Live updates
    # are just to dangerous. There is also the possibility that the
    # live site is running LDAP, in which case user access becomes
    # read only.
    #
    my %result = t::Elive->test_connection(only => 'mock');
    my $auth = $result{auth};

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my %insert_data = (
	loginName => 'some_test_user',
	loginPassword => 'work you b&^*(&rd',
	email => 'test@acme.org',
	role => 3,
	firstName => 'test',
	lastName => 'user'
    );

    my $object = ($class->insert(\%insert_data));
    isa_ok($object, $class);

    foreach (keys %insert_data) {
	ok(Elive::Util::string($object->$_) eq $insert_data{$_}, "$_ property as expected");
    }

    my %update_data = (
	firstName => $insert_data{firstName}.'x',
	loginPassword => $insert_data{loginPassword}.'x',
	);

    $object->update(\%update_data);

    foreach (keys %update_data) {
	ok(Elive::Util::string($object->$_) eq $update_data{$_}, "$_ property as expected");
    }

}

Elive->disconnect;
