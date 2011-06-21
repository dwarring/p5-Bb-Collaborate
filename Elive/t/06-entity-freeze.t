#!perl -T
use warnings; use strict;
use Test::More tests => 34;
use Test::Warn;
use Scalar::Util;

use Elive::Connection;
use Elive::Entity::User;
use Elive::Entity::ParticipantList;
use Elive::Entity::ServerParameters;
use Elive::Entity::Session;
use Elive::Util;

use lib '.';
use t::Elive::MockConnection;

Elive->connection( t::Elive::MockConnection->connect() );

is(Elive::Util::_freeze('123456', 'Int'), '123456', 'simple Int');
is(Elive::Util::_freeze('+123456', 'Int'), '123456', 'Int with plus sign');
is(Elive::Util::_freeze('00123456', 'Int'), '123456', 'Int with leading zeros');

is(Elive::Util::_freeze('-123456', 'Int'), '-123456', 'Int negative');
is(Elive::Util::_freeze('-00123456', 'Int'), '-123456', 'Int negative, leading zeros');
is(Elive::Util::_freeze('+00123456', 'Int'), '123456', 'Int plus sign leading zeros');

is(Elive::Util::_freeze('01234567890000', 'HiResDate'), '1234567890000', 'high precision date');

is(Elive::Util::_freeze(0, 'Int'), '0', 'Int zero');
is(Elive::Util::_freeze('-0', 'Int'), '0', 'Int minus zero');
is(Elive::Util::_freeze('+0', 'Int'), '0', 'Int plus zero');
is(Elive::Util::_freeze('0000', 'Int'), '0', 'Int multiple zeros');

is(Elive::Util::_freeze(0, 'Bool'), 'false', 'Bool 0 => false');
is(Elive::Util::_freeze(1, 'Bool'), 'true', 'Bool 1 => true');

is(Elive::Util::_freeze('abc', 'Str'), 'abc', 'String echoed');
is(Elive::Util::_freeze(' abc ', 'Str'), 'abc', 'String - L/R Trim');
is(Elive::Util::_freeze('  ', 'Str'), '', 'String - Empty');

is(Elive::Util::_freeze('on', 'enumRecordingStates'), 'on', 'recording status - on (lc)');
is(Elive::Util::_freeze('OFF', 'enumRecordingStates'), 'off', 'recording status - off (uc)');
is(Elive::Util::_freeze('rEMotE', 'enumRecordingStates'), 'remote', 'recording status - remote (mixed)');

my $user_data =  {
	userId => '12345678',
	deleted => 0,
	loginPassword => 'test',
	loginName => 'tester',
	email => 'test@test.org',
	role => {roleId => '002'},
	firstName => ' Timmee, the ',
	lastName => 'Tester',
    };

my $user_obj = Elive::Entity::User->construct($user_data);

is_deeply(Elive::Util::_freeze($user_obj,'Elive::Entity::User'), '12345678','object freeze (explicit)');
is_deeply(Elive::Util::_freeze($user_obj,'Int'), '12345678','object freeze (implicit)');

my $user_frozen = Elive::Entity::User->_freeze($user_data);

is_deeply($user_frozen,
	  {                                     
	      email => 'test@test.org',
	      firstName => 'Timmee, the',
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
is(Elive::Entity::User->_freeze($user_data)->{deleted}, 'true',
   'freeze boolean non-zero => "true"');

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

$participant_list_obj = undef;

my $server_parameter_data = {
    meetingId => '0123456789000',
    boundaryMinutes => '+42',
    fullPermissions => 1,
};

my $aliases = Elive::Entity::ServerParameters->_get_aliases;

do {
    ################################################################
    # ++ some slightly off-topic tests
    #
    ok($aliases, 'got server_parameter aliases');
    ok($aliases->{boundary}, 'got server_parameter alias for boundary');
    is($aliases->{boundary}{to}, 'boundaryMinutes', 'alias boundary => boundaryMinutes');
    my $boundary_method_ref;
    my $boundary_mins_method_ref;
    ok($boundary_method_ref =  Elive::Entity::ServerParameters->can('boundary'), 'got boundary method ref');
    ok($boundary_mins_method_ref =  Elive::Entity::ServerParameters->can('boundaryMinutes'), 'got boundaryMinutes method ref');
    is(Scalar::Util::refaddr($boundary_method_ref), Scalar::Util::refaddr($boundary_mins_method_ref), "'boundaryMinutes' method alias for 'boundary'");
    #
    # -- some slightly off-topic tests
    ################################################################
};

is_deeply($aliases->{boundary}, {
    to => 'boundaryMinutes',
    freeze => 1},
    'server_parameter alias for boundaryMinutes - as expected');

my $server_parameter_frozen = Elive::Entity::ServerParameters->_freeze($server_parameter_data);
is_deeply( $server_parameter_frozen, {
    meetingId => 123456789000,
    boundary => 42,
    permissionsOn => 'true'},
    'server parameter freeze from data');

my $session_frozen = Elive::Entity::Session->_freeze(
    {id => 12345, participants => 'alice=2;bob=3;*chair=2;*pleb=3;some_guest (john.doe@acme.org)', repeatEvery => 3, sundaySessionIndicator => 1});

is_deeply($session_frozen,
	  { id => 12345,
	    invitedGuests => 'some_guest (john.doe@acme.org)',
	    invitedModerators => 'alice,*chair',
	    invitedParticipantsList => 'bob,*pleb',
	    repeatEvery => 3,
	    sundaySessionIndicator => 'true'
	  },
	  'Frozen session participants');

