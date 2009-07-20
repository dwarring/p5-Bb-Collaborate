#!perl -T
use warnings; use strict;
use Test::More tests => 72;
use Test::Warn;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::User' );
    use_ok( 'Elive::Entity::ParticipantList' );
    use_ok( 'Elive::Util');
};

ok(Elive::Util::_thaw('123456', 'Int') == 123456, 'simple Int');
ok(Elive::Util::_thaw('+123456', 'Int') == 123456, 'Int with plus sign');
ok(Elive::Util::_thaw('00123456', 'Int') == 123456, 'Int with leading zeros');
ok(Elive::Util::_thaw('-123456', 'Int') == -123456, 'Int negative');
ok(Elive::Util::_thaw('-00123456', 'Int') == -123456, 'Int negative, leading zeros');
ok(Elive::Util::_thaw('+00123456', 'Int') == 123456, 'Int plus sign leading zeros');
ok(Elive::Util::_thaw('01234567890000', 'HiResDate') eq '1234567890000', 'date, leading zero');
ok(Elive::Util::_thaw(0, 'Int') == 0, 'Int zero');
ok(Elive::Util::_thaw('-0', 'Int') == 0, 'Int minus zero');
ok(Elive::Util::_thaw('+0', 'Int') == 0, 'Int plus zero');
ok(Elive::Util::_thaw('0000', 'Int') == 0, 'Int multiple zeros');

ok(!Elive::Util::_thaw('false', 'Bool'), 'Bool false => 0');
ok(Elive::Util::_thaw('true', 'Bool'), 'Bool true => 1');

ok(Elive::Util::_thaw('  abc efg ', 'Str') eq 'abc efg', 'String l-r trimmed');

Elive->connection(Elive::Connection->connect('http://test.org'));

my $user_data = {
    UserAdapter
	=> {
	    Id            => 1239260932,
	    Deleted       => 'false',
	    Email         =>  'bbill@test.com',
	    FirstName     => 'Blinky',
	    LastName      => 'Bill',
	    LoginName     => 'blinkybill',
	    LoginPassword => '',
            Role          => {
		RoleAdapter => {
		    RoleId => 3,
		},
	    },
    },
};

my $user_thawed = Elive::Entity::User->_thaw($user_data);

is_deeply($user_thawed,
	  {
	      email => 'bbill@test.com',
	      firstName => 'Blinky',
	      loginPassword => '',
	      loginName => 'blinkybill',
	      userId => '1239260932',
	      deleted => 0,
	      lastName => 'Bill',
	      role => {
		  roleId => '3'
	      }
	  },
	  'user thawed',
    );

my $user_object = Elive::Entity::User->construct($user_thawed);

isa_ok($user_object, 'Elive::Entity::User', 'constructed object');
isa_ok($user_object->role, 'Elive::Entity::Role', 'constructed object role');

my %user_contents = map {$_ => $user_object->$_} ($user_object->properties);

#
# Round trip verification. We can reconstruct the object from data
#
is_deeply(\%user_contents,
	  {
	      email => 'bbill@test.com',
	      firstName => 'Blinky',
	      loginPassword => '',
	      loginName => 'blinkybill',
	      userId => '1239260932',
	      deleted => 0,
	      lastName => 'Bill',
	      domain => undef,
	      groups => undef,
	      role => bless (
		  {
		      roleId => '3',
		  }, 'Elive::Entity::Role')
	  },
	  'constructed object contents',
    );

{
    #
    # try toggling a boolean flag, while we're at it
    #
    local $user_data->{UserAdapter}{Deleted} = 'true';
    my $user2_thawed = Elive::Entity::User->_thaw($user_data);

    ok($user2_thawed->{deleted}, 'thawing of set boolean flag');
}

#
# Try another simple struct, but this time pick on something that
# includes field alises
#

my $aliases = Elive::Entity::ServerParameters->_get_aliases;
ok($aliases->{requiredSeats}{to} eq 'seats', 'alias: requiredSeats => seats');
ok($aliases->{permissionsOn}{to} eq 'fullPermissions', 'alias: permissionsOn => fullPermissions');

my $server_parameters_data = {
    ServerParametersAdapter
	=> {
	    Id            => 1239260937,
	    RequiredSeats      => 42,  #alias for seats
	    PermissionsOn => 'true',   # alias for fullPermissions
    },
};

my $server_parameters_thawed = Elive::Entity::ServerParameters->_thaw($server_parameters_data);

is_deeply($server_parameters_thawed,
	  {
	      meetingId       => 1239260937,
	      seats           => 42,     #alias for seats
	      fullPermissions => 1,      # alias for fullPermissions
	  },
	  'server parameters thawed',
    );

#
# General nested record level tests, including aliased sub-structures.
# Pick on ParticipantList. This includes Participant and User as
# sub-structure aliases.
#

my @user_alias = ('Participant' => 'User');
my @user_role = (2,3);

#
# Check our underlaying assumptions. Our remaing checks will fail
# unless the Participant -> User alias is defined
#

$aliases = Elive::Entity::Participant->_get_aliases;
ok($aliases, 'got participant list aliases');
ok(my $alias = $aliases->{lcfirst($user_alias[0])}, 'got participant alias');
ok($alias->{to} eq lcfirst($user_alias[1]), 'Participant aliased to user');
#
# Do entire process: unpacking, thawing, constructing
#
my $participant_data = {
    'ParticipantListAdapter' => {
	'MeetingId' => '1239850348031',
	'Participants' => {
	    'Map' => {
		'Entry' => [
		    {
			'Value' => {
			    'ParticipantAdapter' => {
				'Role' => {
				    'RoleAdapter' => {
					'RoleId' => $user_role[0]
				    }
				},
				$user_alias[0] => {
				    'UserAdapter' => {
					'FirstName' => 'David',
					'Role' => {
					    'RoleAdapter' => {
						'RoleId' => '2'
					    }
					},
					'Id' => '1239261045',
					'LoginPassword' => '',
					'LastName' => 'Warring',
					'Deleted' => 'false',
					'Email' => 'david.warring@gmail.com',
					'LoginName' => 'davey_wavey'
				    }
				}
			    }
			},
			'Key' => '1239261045'
		    },
		    {
			'Value' => {
			    'ParticipantAdapter' => {
				'Role' => {
				    'RoleAdapter' => {
					'RoleId' => $user_role[1],
				    }
				},
				$user_alias[1] => {
				    'UserAdapter' => {
					'FirstName' => 'Blinky',
					'Role' => {
					    'RoleAdapter' => {
						'RoleId' => '3'
					    }
					},
					'Id' => '1239260932',
					'LoginPassword' => '',
					'LastName' => 'Bill',
					'Deleted' => 'false',
					'Email' => 'bbill@test.org',
					'LoginName' => 'blinkybill'
				    }
				}
			    }
			},
			'Key' => '1239260932'
		    }
		    ]
	    }
	},
    }
};

##use YAML; die YAML::Dump({user_role => \@user_role,
##			  user_alias => \@user_alias,
##			  participant_list => $participant_data});

my $participant_list_sorbet  = Elive::Entity::ParticipantList->_unpack_results($participant_data);

#
# just some spot checks dereferencing. Tidied up somewhat, but still pretty
# verbose!
#
{
    my $p = $participant_list_sorbet;
    ok($p = $p->{$_}, "found $_ in data")
	foreach(qw{ParticipantListAdapter Participants});

    isa_ok($p, 'ARRAY', 'ParticipantListAdapter->Participants');

    foreach my $n (0..1) {
	ok(my $pn = $p->[$n], "found ParticipantListAdapter->Participant->[$n]");

	foreach ('ParticipantAdapter', $user_alias[$n],
		 qw{UserAdapter Role RoleAdapter RoleId}) {
	    ok($pn = $pn->{$_}, "hash deref $_");
	}

	ok($pn == $_, "sorbet participant ${n}'s role is $_")
	    for $user_role[$n];
    }
}

my $participant_list_thawed = Elive::Entity::ParticipantList->_thaw($participant_list_sorbet);

#
# Run the equivalent checks on the thawed file
#
{
    my $p = $participant_list_thawed;
    ok($p = $p->{$_}, "found $_ in data") for('participants');

    isa_ok($p, 'ARRAY', 'participants');

    for my $n (0..1) {
	ok(my $pn = $p->[$n], "found participants->[$n]");

	foreach (qw{user role roleId}) {
	    ok($pn = $pn->{$_}, "participant $n: hash deref $_");
	}

	ok($pn == $_, "thawed participant ${n}'s role is $_")
	    for $user_role[$n];
    }
}

#
# Now construct and retest
#

my $participant_list_obj =  Elive::Entity::ParticipantList->construct($participant_list_thawed);


{
    my $p = $participant_list_obj;
    ok($p = $p->$_, "found $_ in data") for('participants');

    isa_ok($p, 'Elive::Array::Participants', 'participants');

    foreach my $n (0..1) {
	ok(my $pn = $p->[$n], "found participants->[$n]");

	foreach (qw{user role roleId}) {
	    ok($pn = $pn->$_, "method deref $_");
	}

	ok($pn == $_, "thawed 2nd participants role is $_")
	    for $user_role[$n];
    }
}

#
# Some tests on detecting and applying aliases
#
