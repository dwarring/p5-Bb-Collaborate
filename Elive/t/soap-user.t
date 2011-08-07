#!perl -T
use warnings; use strict;
use Test::More tests => 22;
use Test::Exception;
use Test::Builder;
use version;

use Elive;

use lib '.';
use t::Elive;

my $class = 'Elive::Entity::User' ;
our $t = Test::Builder->new;

use Carp;

#
# restrict our user tests to the mock connections. Live updates
# are just to dangerous. There is also the possibility that the
# live site is running LDAP, in which case user access becomes
# read only.
#
my %opt;
$opt{only} = 'mock'
    unless $ENV{ELIVE_TEST_USER_UPDATES};

my %result = t::Elive->test_connection(%opt);
my $auth = $result{auth};

my $connection_class = $result{class};
my $connection = $connection_class->connect(@$auth);
Elive->connection($connection);

diag "user test url: ".$connection->url;

my $user_login_name = 'soap-user.t-' . t::Elive::generate_id();

my %insert_data = (
    loginName => $user_login_name,
    loginPassword => t::Elive::generate_id(),
    email => 'test@acme.org',
    role => 3,
    firstName => 'test',
    lastName => 'user'
    );

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

#
# try out the changePassword. The password is never returned. The best we
# can do is check that it lives.
#
lives_ok(sub {$pleb_user->change_password( t::Elive::generate_id() )},
	 'change_password - lives');

foreach (keys %update_data) {
    my $expected_value = $_ eq 'loginPassword'
	? ''	# passwords are not echoed
	: $update_data{$_};

    is(Elive::Util::string($pleb_user->$_), $expected_value, "$_ property as expected");
}

my $admin_login_name = 'soap-user.t-admin-' . t::Elive::generate_id();

my $admin_user = $class->insert({loginName => $admin_login_name, # alias for loginName
				 role => 0,
				 loginPassword => t::Elive::generate_id(),
				 email => 'test@acme.org'},);

my $admin_id = $admin_user->userId;

$admin_user = undef;
$admin_user = $class->retrieve($admin_id);
isa_ok($admin_user, $class, 'admin user - retrieve by id');

our $elm_3_3_4_or_better =  (version->declare( $connection->server_details->version )->numify
			     > version->declare( '10.0.1' )->numify);
my $is_mock_connection = $connection_class->isa('t::Elive::MockConnection');

if ($elm_3_3_4_or_better || $is_mock_connection) {

    $admin_user = undef;
    $admin_user = $class->retrieve($admin_login_name);
    isa_ok($admin_user, $class, 'admin user - retrieve by loginName');
    is($admin_user->userId, $admin_id, 'admin user - userId');

}
else {
    $t->skip('skipping retrive by loginName for Elive < 10.0.1')
	for (1 .. 2);
}

lives_ok(
    sub {
	$admin_user->set('email' => 'bbill@test.org',
			 role => 3,);
    },
    "setter on live entity - lives"
    );

dies_ok( sub{$admin_user->update}, "update of admin user without -force - dies");
lives_ok( sub{$admin_user->update(undef, force => 1)}, "update of admin user with -force - lives");
#
# restore the user's admin status
#
$admin_user->update({role => 0}, force => 1);

dies_ok(sub {$admin_user->delete},"delete admin user without -force - dies");
lives_ok(sub {$admin_user->delete(force => 1)},"delete admin user with -force - lives");

dies_ok(
    sub {$admin_user->set('email' => 'blinky@test.org')},
    "setter on deleted entity - dies"
    );

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
