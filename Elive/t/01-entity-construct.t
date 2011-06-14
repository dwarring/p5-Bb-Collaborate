#!perl -T
use warnings; use strict;
use Test::More tests => 47;
use Test::Warn;

use Carp; $SIG{__DIE__} = \&Carp::confess;

use Elive::Connection;
use Elive::Entity::ParticipantList;
use Elive::Entity::Group;
use Elive::Entity::Meeting;
use Elive::Entity::User;

use lib '.';
use t::Elive::MockConnection;

Elive->connection( t::Elive::MockConnection->connect() );

my $participant_list = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 123456,
	participants => [
	    {
		user => {userId => 112233,
			 loginName => 'test_user',
		},
		role => {roleId => 2},
	    },
	    {
		user => {userId => 223344,
			 loginName => 'test_user2',
		},
		role => {roleId => 3},
	    },
	    
	    {
		user => {userId => 'dave',
			 loginName => 'test_user2',
		},
		role => {roleId => 3},
	    }
	    
	    ],
    },
    );

isa_ok($participant_list, 'Elive::Entity::ParticipantList', 'participant');
is($participant_list->stringify, "123456", 'participant list stringified');

can_ok($participant_list, 'meetingId');
can_ok($participant_list, 'participants');

my $participants = $participant_list->participants;
isa_ok($participants, 'Elive::Entity::ParticipantList::Participants');

ok(@$participants == 3, 'all participants constructed');
isa_ok($participants->[0], 'Elive::Entity::ParticipantList::Participant');

$participants->add({
    user => {userId => 'late_comer',
	     loginName => 'late_comer',
	 },
    role => {roleId => 3},
});

ok(@$participants == 4, 'participants added');
isa_ok($participants->[-1], 'Elive::Entity::ParticipantList::Participant');
is($participants->[-1]->user->userId, 'late_comer', 'added participant value');

$participant_list->revert;

is($participants->[0]->user->stringify, '112233', 'user stringified');

is($participants->[0]->role->stringify, '2', 'role stringified');

is($participants->[0]->stringify, '112233=2', 'participant stringified');

is($participants->[2]->stringify, 'dave=3', 'participant stringified');

is($participants->stringify, '112233=2;223344=3;dave=3;late_comer=3',
   'participants stringification');

is($participant_list->participants->[0]->user->loginName, 'test_user',
   'participant dereference');

#
# test participant list coercian
#
my $participant_list_2 = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 234567,
	participants => '1111;2222=2;alice=3'
    });

my $participants_2 = $participant_list_2->participants;
is($participants_2->[0]->user->userId, 1111, 'participant list user[0]');
is($participants_2->[0]->role->roleId, 3, 'participant list role[0] (defaulted)');
is($participants_2->[1]->user->userId, 2222, 'participant list user[1]');
is($participants_2->[1]->role->roleId, 2, 'participant list role[1] (explicit)');
is($participants_2->[2]->user->userId,'alice', 'participant list user[2] (alphanumeric - ldap compat)');

my $participant_list_3 = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 345678,
	participants => [1122,'2233=2']
    });

my $participants_3 = $participant_list_3->participants;
is($participants_3->[0]->user->userId , 1122, 'participant list user');
is($participants_3->[0]->role->roleId , 3, 'participant list role (defaulted)');
is($participants_3->[1]->user->userId , 2233, 'participant list user');
is($participants_3->[1]->role->roleId , 2, 'participant list role (explicit)');

my $member_list_1 = Elive::Entity::Group->construct(
								   {
        groupId => 54321,
	name => 'group_1',
        members => '212121,222222,fred'
	});

my $members_1 = $member_list_1->members;
is($members_1->[0], 212121, 'member list user[0]');
is($members_1->[1], 222222, 'member list user[1]');
is($members_1->[2], 'fred', 'member list user[2] (alphanumeric - ldap compat)');
    ;

$members_1->add('late_comer');
is($members_1->[-1], 'late_comer', 'member add');
is($members_1->stringify, '212121,222222,fred,late_comer', 'member list stringification');

$member_list_1->revert;

my $member_list_2 = Elive::Entity::Group->construct(
								   {
        groupId => 65432,
	name => 'group_2',
        members => [112233,'223344','alice', Elive::Entity::User->construct({userId => 'bob', loginName => 'bob'})]
	});

my $members_2 = $member_list_2->members;
is($members_2->[0], 112233,  'member list user[0] (integer)');
is($members_2->[1], 223344,  'member list user[1] (string)');
is($members_2->[2], 'alice', 'member list user[2] (alphanumeric - ldap compat)');
is($members_2->[3], 'bob',   'member list user[3] (object cast)');

my $meeting =  Elive::Entity::Meeting->construct({
    meetingId => '112233445566',
    name => 'test meeting',
    start => '1234567890123',
    end => '1231231230123',
						 });

isa_ok($meeting, 'Elive::Entity::Meeting');
is($meeting->name, 'test meeting', 'meeting name');
is($meeting->start, '1234567890123', 'meeting start (hires coercian)');
is($meeting->end, '1231231230123', 'meeting end (hires explicit)');

#
# test uncoercian of objects to simple values (e.g. primary key).
#

my $participant_list_4 = Elive::Entity::ParticipantList->construct(
								   {
        meetingId => $meeting,
        participants => [1122,'2233=2']
	});

is($participant_list_4->meetingId , $meeting->meetingId, "object => id cast on construct (primary key)");
is($participant_list_4->participants->stringify, '1122=3;2233=2', "participants stringification");

do {

    ## tests on nested group construction

    my $group =  Elive::Entity::Group->construct( {
	name => 'Top level group',
	groupId => '1111',
	members => [
	    2222,
	    3333,
	    {
		name => 'sub group',
		groupId => 444,
		members => [
		    '4141',
		    '4242',
		    '3333', # deliberate duplicate
		    ],
	    }
	]
     });

    is($group->name, 'Top level group', 'nested group - top level name');
    is($group->groupId, '1111', 'nested group - top level id');

    my $members = $group->members;
    isa_ok($members,'ARRAY', 'group members');
    is(scalar @$members, 3, 'group members - cardinality');
    is($members->[0], '2222', 'group member - simple element');
    isa_ok($members->[2], 'Elive::Entity::Group', 'group member - subgroup');

    my @all_members = $group->expand_members;
    is_deeply(\@all_members, [2222, 3333, 4141, 4242], 'group - all_members()');
};
