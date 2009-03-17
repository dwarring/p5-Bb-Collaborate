#!perl -T
use warnings; use strict;
use Test::More tests => 13;
use Test::Warn;

package Elive::Connection::TestStub;

sub url {return 'http://elive.test.org/test'};

########################################################################

package main;

BEGIN {
	use_ok( 'Elive::Entity::ParticipantList' );
};

my $connection_stub = bless {}, 'Elive::Connection::TestStub';

my $participant_list = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 123456,
	participants => [
	    {
		user => {userId => 123456,
			 loginName => 'test_user',
		},
		role => {roleId => 2},
	    },
	    {
		user => {userId => 112233,
			 loginName => 'test_user2',
		},
		role => {roleId => 3},
	    }
	    
	    ],
    },
    connection => $connection_stub,
    );

isa_ok($participant_list, 'Elive::Entity::ParticipantList', 'participant');
ok($participant_list eq "123456", 'particpiant list stringified');

can_ok($participant_list, 'meetingId');
can_ok($participant_list, 'participants');

my $participants = $participant_list->participants;
isa_ok($participants, 'Elive::Array');

ok(@$participants == 2, 'all particpiants constructed');
isa_ok($participants->[0], 'Elive::Entity::Participant');

ok($participants->[0]->user eq '123456', 'user stringified');

ok($participants->[0]->role eq '2', 'role stringified');

ok($participants->[0] eq '123456=2', 'particpiant stringified');

ok($participants eq '112233=3;123456=2',
   'participants sorting and stringification');

ok($participant_list->participants->[0]->user->loginName eq 'test_user',
   'dereference');
