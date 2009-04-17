#!perl -T
use warnings; use strict;
use Test::More tests => 14;
use Test::Warn;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::ParticipantList' );
};

Elive->connection(Elive::Connection->new('http://test.org'));

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
	    }
	    
	    ],
    },
    );

isa_ok($participant_list, 'Elive::Entity::ParticipantList', 'participant');
ok($participant_list->stringify eq "123456", 'particpiant list stringified');

can_ok($participant_list, 'meetingId');
can_ok($participant_list, 'participants');

my $participants = $participant_list->participants;
isa_ok($participants, 'Elive::Array');

ok(@$participants == 2, 'all particpiants constructed');
isa_ok($participants->[0], 'Elive::Entity::Participant');

ok($participants->[0]->user->stringify eq '112233', 'user stringified');

ok($participants->[0]->role->stringify eq '2', 'role stringified');

ok($participants->[0]->stringify eq '112233=2', 'particpiant stringified');

ok($participants->stringify eq '112233=2;223344=3',
   'participants stringification');

ok($participant_list->participants->[0]->user->loginName eq 'test_user',
   'dereference');
