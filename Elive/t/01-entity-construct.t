#!perl -T
use warnings; use strict;
use Test::More tests => 43;
use Test::Warn;

use Carp; $SIG{__DIE__} = \&Carp::confess;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::ParticipantList' );
    use_ok( 'Elive::Entity::Group' );
    use_ok( 'Elive::Entity::Meeting' );
};

Elive->connection(Elive::Connection->connect('http://test.org'));

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
ok($participant_list->stringify eq "123456", 'participant list stringified');

can_ok($participant_list, 'meetingId');
can_ok($participant_list, 'participants');

my $participants = $participant_list->participants;
isa_ok($participants, 'Elive::Array::Participants');

ok(@$participants == 3, 'all participants constructed');
isa_ok($participants->[0], 'Elive::Entity::Participant');

$participants->add({
    user => {userId => 'late_comer',
	     loginName => 'late_comer',
	 },
    role => {roleId => 3},
});

ok(@$participants == 4, 'participants added');
isa_ok($participants->[-1], 'Elive::Entity::Participant');
ok($participants->[-1]->user->userId eq 'late_comer', 'added participant value');

$participant_list->revert;

ok($participants->[0]->user->stringify eq '112233', 'user stringified');

ok($participants->[0]->role->stringify eq '2', 'role stringified');

ok($participants->[0]->stringify eq '112233=2', 'participant stringified');

ok($participants->[2]->stringify eq 'dave=3', 'participant stringified');

ok($participants->stringify eq '112233=2;223344=3;dave=3;late_comer=3',
   'participants stringification');

ok($participant_list->participants->[0]->user->loginName eq 'test_user',
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
ok($participants_2->[0]->user->userId eq 1111, 'participant list user[0]');
ok($participants_2->[0]->role->roleId == 3, 'participant list role[0] (defaulted)');
ok($participants_2->[1]->user->userId eq 2222, 'participant list user[1]');
ok($participants_2->[1]->role->roleId == 2, 'participant list role[1] (explicit)');
ok($participants_2->[2]->user->userId eq 'alice', 'participant list user[2]');

my $participant_list_3 = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 345678,
	participants => [1122,'2233=2']
    });

my $participants_3 = $participant_list_3->participants;
ok($participants_3->[0]->user->userId == 1122, 'participant list user');
ok($participants_3->[0]->role->roleId == 3, 'participant list role (defaulted)');
ok($participants_3->[1]->user->userId == 2233, 'participant list user');
ok($participants_3->[1]->role->roleId == 2, 'participant list role (explicit)');

my $member_list_1 = Elive::Entity::Group->construct(
								   {
        groupId => 54321,
	name => 'group_1',
        members => '212121;222222;fred'
	});

my $members_1 = $member_list_1->members;
ok($members_1->[0] eq 212121, 'member list user');
ok($members_1->[1] eq 222222, 'member list user');
ok($members_1->[2] eq 'fred', 'member list user');
    ;

$members_1->add('late_comer');
ok($members_1->[-1] eq 'late_comer', 'member add');
ok($members_1->stringify eq '212121;222222;fred;late_comer', 'member list stringification');

$member_list_1->revert;

my $member_list_2 = Elive::Entity::Group->construct(
								   {
        groupId => 65432,
	name => 'group_2',
        members => [112233,'223344','trev']
	});

my $members_2 = $member_list_2->members;
ok($members_2->[0] eq 112233, 'member list user[0]');
ok($members_2->[1] eq 223344, 'member list user[1]');
ok($members_2->[2] eq 'trev', 'member list user[2]');

my $meeting =  Elive::Entity::Meeting->construct({
    meetingId => '112233445566',
    name => 'test meeting',
    start => '1234567890123',
    end => '1231231230123',
						 });

isa_ok($meeting, 'Elive::Entity::Meeting');
ok($meeting->name eq 'test meeting', 'meeting name');
ok($meeting->start eq '1234567890123', 'meeting start (hires coercian)');
ok($meeting->end eq '1231231230123', 'meeting end (hires explicit)');

#
# test uncoercian of objects to simple values (e.g. primary key).
#

my $participant_list_4 = Elive::Entity::ParticipantList->construct(
								   {
        meetingId => $meeting,
        participants => [1122,'2233=2']
	});

ok($participant_list_4->meetingId == $meeting->meetingId, "uncoercian on construct (primary key)");
ok($participant_list_4->participants->stringify eq '1122=3;2233=2', "participants stringification");
