#!perl
use warnings; use strict;
use Test::More tests => 7;
use Test::Exception;

use Elive;
use Elive::Entity::User;
use Elive::Entity::Group;

use lib '.';
use t::Elive;

my $class = 'Elive::Entity::Group';

use Carp;
$SIG{__DIE__} = \&Carp::confess;
#
# restrict our user tests to mock connections. Live updates
# are just to dangerous. There is also the possibility that the
# live site is running LDAP, in which case both user and group access
# become read only.
#
my %opt;
$opt{only} = 'mock'
    unless $ENV{ELIVE_TEST_GROUP_UPDATES};

my %result = t::Elive->test_connection(%opt);
my $auth = $result{auth};

my $connection_class = $result{class};
my $connection = $connection_class->connect(@$auth);
Elive->connection($connection);

diag "group test url: ".$connection->url;

my @usernames = qw(test_user1 test_user2 test_user3 alice bob trev);
my @users;
my %user_ids;

my $base = t::Elive::generate_id();
my @inserted_users;

foreach my $username (@usernames) {
    my ($user) = eval {Elive::Entity::User->get_by_loginName($username)};

    unless ($user) {
	my %insert_data = (
	    loginName => $username,
	    loginPassword => t::Elive::generate_id(),
	    email => $username.'@acme.org',
	    role => 3,
	    firstName => $username,
	    lastName => 'user'
	    );

	$user = Elive::Entity::User->insert(\%insert_data);
	push (@inserted_users, $user);
    }

    push (@users, $user);
    $user_ids{$username} = $user->userId;
}

my $group_name = '27-soap-group.t - basic '.t::Elive::generate_id();

my $group = $class->insert(
    {name => $group_name,
     members => \@users
    });

isa_ok($group, $class, 'inserted group');
my @expected_members = sort map {$_->userId} @users;
my @actual_members = sort @{$group->members};
is_deeply(\@actual_members, \@expected_members, 'members after insert');

#
# try out alias, both on insert and update. assumes that we have the
# following aliases set up:
#    groupName => name
#    gourpMembers => members

my $group2 = $class->insert({
	groupName => $group_name.'#2',  # groupName => name
	members => \@users
    });

is($group2->{name}, $group_name.'#2', 'insert alias (groupName aliased to name)');

use Carp; $SIG{__DIE__} = \&Carp::confess;
use Carp; $SIG{__WARN__} = \&Carp::cluck;
my @member_ids = sort ($user_ids{alice}, $user_ids{bob});
$group2->update({name => $group_name.'#3', groupMembers => \@member_ids});

is_deeply($group2->{name}, $group_name.'#3', 'update of group name');
my @actual_members2 = sort @{ $group2->{members} };
is_deeply(\@actual_members2, \@member_ids, 'update alias (groupMembers aliased to members)');

#
# try some variations
#
my @members2 = sort ($user_ids{alice}, $user_ids{bob}, $user_ids{trev});
$group2->members(\@members2);
$group2->update;

@actual_members2 = sort @{ $group2->{members} };
is_deeply(\@actual_members2, \@members2, 'update alias#2 (groupMembers aliased to members)');

lives_ok(sub {$group->delete; $group2->delete}, 'group delete - lives');

foreach (@inserted_users) {
    $_->delete;
}

Elive->disconnect;


