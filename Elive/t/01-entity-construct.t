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
ok($participant_list eq "123456", 'particpiant list stringified');

can_ok($participant_list, 'meetingId');
can_ok($participant_list, 'participants');

my $participants = $participant_list->participants;
isa_ok($participants, 'Elive::Array');

ok(@$participants == 2, 'all particpiants constructed');
isa_ok($participants->[0], 'Elive::Entity::Participant');

ok($participants->[0]->user eq '112233', 'user stringified');

ok($participants->[0]->role eq '2', 'role stringified');

ok($participants->[0] eq '112233=2', 'particpiant stringified');

ok($participants->stringify eq '112233=2;223344=3',
   'participants stringification');

diag "participants: ".$participants->stringify;

ok($participant_list->participants->[0]->user->loginName eq 'test_user',
   'dereference');

#
# To do: Elive::Entity::Participant's coercian rules allow users and
# roles to be either entities or ints?
#
#use Carp; $SIG{__DIE__} = \&Carp::confess;
#
#my $participant_list_shallow = Elive::Entity::ParticipantList->construct(
#    {
#	meetingId => 234567,
#	participants => [
#	    {
#		user => 223344,  # deliberate overlap with previous test
#		role => 2,
#	    },
#	    {
#		user => 334455,
#		role => 3,
#	    }
#	    
#	    ],
#    },
#    );
#
#use YAML;
#diag YAML::Dump($participant_list_shallow);
