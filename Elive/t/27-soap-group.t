#!perl
use warnings; use strict;
use Test::More tests => 4;
use Test::Exception;

use Elive;
use Elive::Entity::User;

use lib '.';
use t::Elive;

my $class = 'Elive::Entity::Group' ;

use_ok($class);

use Carp;
$SIG{__DIE__} = \&Carp::confess;

#
# restrict our user tests to the mock database. Live updates
# are just to dangerous. There is also the possibility that the
# live site is running LDAP, in which case both user and group access
# become read only.
#
my %result = t::Elive->test_connection(only => 'mock');
my $auth = $result{auth};

my $connection_class = $result{class};
my $connection = $connection_class->connect(@$auth);
Elive->connection($connection);

my @usernames = qw(test_user1 test_user2 test_user3);
my @users;

foreach my $username (@usernames) {
    my ($user) = eval {Elive::Entity::User->get_by_loginName($username)};

    unless ($user) {
	my %insert_data = (
	    loginName => $username,
	    loginPassword => t::Elive::generate_password(),
	    email => $username.'@acme.org',
	    role => 3,
	    firstName => $username,
	    lastName => 'user'
	    );

	$user = Elive::Entity::User->insert(\%insert_data);
    }

    push (@users, $user);
}

my $group_name = '27-soap-group.t - basic';

## mock db doesn't support list yet. We know our mock table is empty anyway!
##my ($existing_group) = grep {$_->name eq $group_name} @{ $class->list() };
##
##if ($existing_group) {
##    diag "deleting existing group: ".$existing_group->name;
##    $existing_group->delete;
##}

my $group = $class->insert(
    {name => $group_name,
     members => \@users
    });


isa_ok($group, $class, 'inserted group');
my @expected_members = sort map {$_->userId} @users;
my @actual_members = sort @{$group->members};
is_deeply(\@actual_members, \@expected_members, 'members after insert');

## todo: implement group updates
##my @expected_members_1 = ($expected_members[0], $expected_members[2]);

##$group->members(\@expected_members_1);
##$group->update;
##my @actual_members_1 = sort @{$group->members};
##is_deeply(\@actual_members_1, \@expected_members_1, 'members after update');

lives_ok(sub {$group->delete}, 'group delete - lives');

Elive->disconnect;


