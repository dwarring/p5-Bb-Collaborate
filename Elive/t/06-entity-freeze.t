#!perl -T
use warnings; use strict;
use Test::More tests => 21;
use Test::Warn;

use Carp; $SIG{__DIE__} = \&Carp::confess;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::User' );
    use_ok( 'Elive::Entity::ParticipantList' );
    use_ok( 'Elive::Util');
};

ok(Elive::Util::_freeze('123456', 'Int') eq '123456', 'simple Int');
ok(Elive::Util::_freeze('+123456', 'Int') eq '123456', 'Int with plus sign');
ok(Elive::Util::_freeze('00123456', 'Int') eq '123456', 'Int with leading zeros');
ok(Elive::Util::_freeze('-123456', 'Int') eq '-123456', 'Int negative');
ok(Elive::Util::_freeze('-00123456', 'Int') eq '-123456', 'Int negative, leading zeros');
ok(Elive::Util::_freeze('+00123456', 'Int') eq '123456', 'Int plus sign leading zeros');
ok(Elive::Util::_freeze(0, 'Int') eq '0', 'Int zero');
ok(Elive::Util::_freeze('-0', 'Int') eq '0', 'Int minus zero');
ok(Elive::Util::_freeze('+0', 'Int') eq '0', 'Int plus zero');
ok(Elive::Util::_freeze('0000', 'Int') eq '0', 'Int multiple zeros');

ok(Elive::Util::_freeze(0, 'Bool') eq 'false', 'Bool 0 => false');
ok(Elive::Util::_freeze(1, 'Bool') eq 'true', 'Bool 1 => true');

ok(Elive::Util::_freeze('abc', 'Str') eq 'abc', 'String echoed');

Elive->connection(Elive::Connection->connect('http://test.org'));

my $user_data =  {
	userId => '12345678',
	deleted => 0,
	loginPassword => 'test',
	loginName => 'tester',
	email => 'test@test.org',
	role => {roleId => '+002'},
	firstName => 'Timmee',
	lastName => 'Tester',
    };

my $user_frozen = Elive::Entity::User->_freeze($user_data);

is_deeply($user_frozen,
	  {                                     
	      email => 'test@test.org',
	      firstName => 'Timmee',
	      loginPassword => 'test',
	      loginName => 'tester',
	      userId => 12345678,
	      lastName => 'Tester',
	      deleted => 'false',
	      role => '2'
	  },
	  'freeze user from data'
    );

$user_data->{deleted} = 1;
ok(Elive::Entity::User->_freeze($user_data)->{deleted} eq 'true',
   'freeze true boolean value');

my $participant_list_frozen = Elive::Entity::ParticipantList->_freeze(
    {
	meetingId => 123456,
	participants => [
	    {
		user => {userId => 112233},
		role => {roleId => 2},
	    },
	    {
		user => {userId => 223344},
		role => {roleId => 3},
	    }
	    
	    ],
    },
    );

is_deeply($participant_list_frozen,
	  {
	      meetingId => 123456,
	      #
	      # note: participants are frozen to users
	      #
	      users => '112233=2;223344=3',
	  },
	  'participant_list freeze from data'
    );

my $participant_list_obj = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 234567,
	participants => [
	    {
		user => {userId => 334455},
		role => {roleId => 2},
	    },
	    {
		user => {userId => 667788},
		role => {roleId => 3},
	    }
	    
	    ],
    },
    );

my $participant_list_frozen2 = Elive::Entity::ParticipantList->_freeze(
    $participant_list_obj
    );

is_deeply($participant_list_frozen2,
	  {
	      meetingId => 234567,
	      #
	      # note: participants are frozen to users
	      #
	      users => '334455=2;667788=3'
	  },
	  'participant_list freeze from object'
    );


