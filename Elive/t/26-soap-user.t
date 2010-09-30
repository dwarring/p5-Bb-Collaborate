#!perl
use warnings; use strict;
use Test::More tests => 17;
use Test::Exception;

use Elive;

use lib '.';
use t::Elive;

my $class = 'Elive::Entity::User' ;

use Carp;

#
# restrict our user tests to the mock connections. Live updates
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
    loginPassword => t::Elive::generate_id(),
    email => 'test@acme.org',
    role => 3,
    firstName => 'test',
    lastName => 'user'
    );

if (my $existing_user = $class->get_by_loginName($insert_data{loginName})) {
    diag "deleting existing user: $insert_data{loginName}";
    $existing_user->delete;
}

my $pleb_user = ($class->insert(\%insert_data));
isa_ok($pleb_user, $class);

foreach (keys %insert_data) {
    my $expected_value = $_ eq 'loginPassword'
	? ''	# passwords are not echoed
	: $insert_data{$_};

    is(Elive::Util::string($pleb_user->$_), $expected_value, "$_ property as expected");
}

my %update_data = (
    firstName => $insert_data{firstName}.'x',
    loginPassword => $insert_data{loginPassword}.'x',
    );

$pleb_user->update(\%update_data);

foreach (keys %update_data) {
    my $expected_value = $_ eq 'loginPassword'
	? ''	# passwords are not echoed
	: $update_data{$_};

    is(Elive::Util::string($pleb_user->$_), $expected_value, "$_ property as expected");
}

if (my $existing_user = $class->get_by_loginName('test_admin')) {
    diag "deleting existing user: test_admin";
    $existing_user->delete;
}

my $admin_user = $class->insert({loginName => "test_admin",
				 role => 0,
				 loginPassword => t::Elive::generate_id(),
				 email => 'test@acme.org'},);
my $admin_id = $admin_user->userId;

$admin_user = undef;
$admin_user = $class->retrieve([$admin_id]);
isa_ok($admin_user, $class, 'admin user before delete');

lives_ok(
    sub {$admin_user->set('email' => 'bbill@test.org')},
    "setter on live entity - lives"
    );

dies_ok(sub {$admin_user->delete},"delete admin user without -force - dies");
lives_ok(sub {$admin_user->delete(force => 1)},"delete admin user with -force - lives");

dies_ok(
    sub {$admin_user->set('email' => 'blinky@test.org')},
    "setter on deleted entity - dies"
    );

$admin_user->revert;

$admin_user = undef;
$admin_user = $class->retrieve([$admin_id]);
#
# Delete behaves differently on different versions of elm
#
ok(!$admin_user || $admin_user->deleted,'admin user deleted');

lives_ok(sub {$pleb_user->delete},"delete regular user - lives");

my $login_user = $connection->login;
dies_ok(sub {$login_user->delete},"delete login user - dies");

Elive->disconnect;
