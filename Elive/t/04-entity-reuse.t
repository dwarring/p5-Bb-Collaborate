#!perl -T
use warnings; use strict;
use Test::More tests => 4;
use Test::Warn;

package main;

use Elive::Connection;
use Elive::Entity::Group;
use Elive::Entity::ParticipantList;

use Scalar::Util;

Elive->connection(Elive::Connection->connect('http://test.org'));

my $group = Elive::Entity::Group->construct(
    {
	groupId => 111111,
	name => 'test group',
	members => [
	    123456, 112233
	    ]
    },
    );

isa_ok($group, 'Elive::Entity::Group', 'group');
is($group->members->[1], 112233, 'can access group members');

my $user1 =  Elive::Entity::User->construct(
    {userId => 11111,
     loginName => 'pete'},
    );

my $user1_again = Elive::Entity::User->retrieve([11111],
    reuse => 1);

ok(_same_ref($user1, $user1_again), 'basic entity reuse');

my $user2 =  Elive::Entity::User->construct(
    {userId => 22222,
     loginName => 'pete'},
    );

my $participant_list = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 9999,
	participants => [
	    {
		user => {userId => 22222,
			 loginName => 'repeat',
		},
		role => {roleId => 2},
	    },
	    {
		user => {userId => 33333,
			 loginName => 'test_user3',
		},
		role => {roleId => 3},
	    }
	    
	    ],
    },
    );

_dump_objs();

my $user2_again = $participant_list->participants->[0]{user};

ok(_same_ref($user2, $user2_again), 'nested reuse');

########################################################################

sub _dump_objs {
    my $live_objects = Elive::Entity->live_entities;

    diag "Elive Objects:\n";
    foreach (keys %$live_objects) {
	my $o = $live_objects->{$_};
	diag "\t$_ = ".Scalar::Util::refaddr($o)
	    if ($o);
    }
    print "\n";
}

sub _same_ref {
    my $a1 = Scalar::Util::refaddr(shift);
    my $a2 = Scalar::Util::refaddr(shift);

    return $a1 && $a1 eq $a2
}

