#!perl -T
use warnings; use strict;
use Test::More;
use Test::Exception;
use Test::Builder;
use Elive;

use lib '.';
use t::Elive;

my $t = Test::Builder->new();

my $class = 'Elive::Entity::User' ;

use Carp;
use Scalar::Util;
use Try::Tiny;

my $MODULE = 'Test::Taint';
eval "use $MODULE";
plan skip_all => "$MODULE not available for taint tests"
    if $@;

plan tests => 15;
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

taint_checking_ok();

my $password_untainted = 'secret_'.t::Elive::generate_id();
taint(my $password_tainted = $password_untainted);

untainted_ok($password_untainted, 'tainted sanity 1');
tainted_ok($password_tainted, 'tainted sanity 2');
# this is used internallly to test for taintedness
ok( Scalar::Util::tainted($password_tainted), 'tainted sanity 3');
my $password_ref = Elive::Util::_clone({pass => $password_tainted});
ok( Scalar::Util::tainted($password_ref->{pass}), 'Elive::Util::clone preserves tainting');

my %insert_data = (
    loginName => 'some_test_user',
    loginPassword => $password_tainted,
    email => 'test@acme.org',
    role => 3,
    firstName => 'test',
    lastName => 'user'
    );

if (my $existing_user = try {$class->get_by_loginName($insert_data{loginName})}) {
    diag "deleting existing user: $insert_data{loginName}";
    $existing_user->delete;
}

my $pleb_user;

dies_ok(sub {$pleb_user = ($class->insert(\%insert_data))},
	'insert of tainted data - dies');

$insert_data{loginPassword} = $password_untainted;

lives_ok(sub {$pleb_user = ($class->insert(\%insert_data))},
	'insert of untainted data - lives');

my $firstname_untainted = $insert_data{firstName}.'x';
taint (my $firstname_tainted = $firstname_untainted);

my %update_data = (
    firstName => $firstname_tainted,
    loginPassword => $insert_data{loginPassword}.'x',
    );

dies_ok( sub {$pleb_user->update(\%update_data)}, 'update with tainted data - dies');

$update_data{firstName} = $firstname_untainted;
lives_ok( sub {$pleb_user->update(\%update_data)}, 'update with untainted data - lives');

my $user_id_untainted = $pleb_user->userId;
taint(my $user_id_tainted = $user_id_untainted);

$pleb_user = undef;
dies_ok( sub { $pleb_user = $class->retrieve([$user_id_tainted]) },
	 'retrieve on tainted data - dies');

lives_ok( sub { $pleb_user = $class->retrieve([$user_id_untainted]) },
	 'retrieve on untainted data - lives');

isa_ok($pleb_user, $class, 'retrieved user');

if ($connection_class->isa('t::Elive::MockConnection')) {

    $t->skip('skipping "list" test on mock connection')
	for (1 .. 3);

}
else {

    my @pleb_users;

    dies_ok( sub {
	@{ $class->list( filter => "firstName = '".$firstname_tainted. "'" );
	} },
	     '"list()" with tainted filter - dies'
	);

    lives_ok( sub {
	@pleb_users = @{ $class->list( filter => "firstName = '".$firstname_untainted. "'" );
	    } },
	     '"list()" with untainted filter - lives'
	);

    isa_ok($pleb_users[0], $class, '"list()" output');
}

$pleb_user->delete;

Elive->disconnect;
