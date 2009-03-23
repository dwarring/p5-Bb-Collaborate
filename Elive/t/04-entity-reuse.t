#!perl -T
use warnings; use strict;
use Test::More tests => 7;
use Test::Warn;

package main;

BEGIN {
    use_ok( 'Data::Entity::Repository' );
    use_ok( 'Elive::Entity::Group' );
    use_ok( 'Elive::Entity::ParticipantList' );
};

use Scalar::Util;

Elive->connection(Data::Entity::Repository->new('http://test.org'));

my $group = Elive::Entity::Group->construct(
    {
	groupId => 111111,
	members => [
	    123456, 112233
	    ]
    },
    );

isa_ok($group, 'Elive::Entity::Group', 'group');
ok($group->members->[1] == 112233, 'can access group members');

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

_dump_objs();

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
    my $live_objects = Data::Entity::Stored->live_entities;

    print "Elive Objects:\n";
    foreach (keys %$live_objects) {
	my $o = $live_objects->{$_};
	print "\t$_ = ".Scalar::Util::refaddr($o)."\n"
	    if ($o);
    }
    print "\n";
}

sub _same_ref {
    my $a1 = Scalar::Util::refaddr(shift);
    my $a2 = Scalar::Util::refaddr(shift);

    return $a1 && $a1 eq $a2
}

