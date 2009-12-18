#!perl
use warnings; use strict;
use Test::More tests => 16;
use Test::Exception;

use lib '.';
use t::Elive;

my $class = 'Elive::Entity::User' ;

use Carp;
$SIG{__DIE__} = \&Carp::confess;

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

my $pleb_user = ($class->insert(\%insert_data));
isa_ok($pleb_user, $class);

foreach (keys %insert_data) {
    ok(Elive::Util::string($pleb_user->$_) eq $insert_data{$_}, "$_ property as expected");
}

my %update_data = (
    firstName => $insert_data{firstName}.'x',
    loginPassword => $insert_data{loginPassword}.'x',
    );

$pleb_user->update(\%update_data);

foreach (keys %update_data) {
    ok(Elive::Util::string($pleb_user->$_) eq $update_data{$_}, "$_ property as expected");
}

my $admin_user = $class->insert({loginName => "admin", role => 0});
my $admin_id = $admin_user->userId;

$admin_user = undef;

lives_ok(sub {$admin_user = $class->retrieve([$admin_id])}
	 ,'retrieve before delete - lives');
isa_ok($admin_user, $class);

dies_ok(sub {$admin_user->delete},"delete admin user without -force - dies");
lives_ok(sub {$admin_user->delete(force => 1)},"delete admin user with -force - lives");
dies_ok(sub {$class->retrieve([$admin_id])},'retrieve user after delete - dies');

lives_ok(sub {$pleb_user->delete},"delete regular user - lives");

my $login_user = $connection->login;
dies_ok(sub {$login_user->delete},"delete login user - dies");

Elive->disconnect;
