#!perl
use warnings; use strict;
use Test::More tests => 26;
use Test::Exception;

package main;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Meeting' );
    use_ok( 'Elive::Entity::MeetingParameters' );
    use_ok( 'Elive::Entity::ServerParameters' );
};

my $class = 'Elive::Entity::Meeting' ;

SKIP: {

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	22)
	unless $auth;

    Elive->connect(@$auth);

    my %meeting_str_data = (
	name => 'test meeting, generated by t/21-soap-meeting.t',
	password => 'test', # what else?
    );

    my %meeting_int_data = (
	facilitatorId => Elive->login->userId,
	start => time() * 1000,
	end => (time()+900) * 1000,
##	privateMeeting => 1,
	
    );

    my $meeting = $class->insert({%meeting_int_data, %meeting_str_data});

    isa_ok($meeting, $class, 'meeting');

    foreach ('name') {
	#
	# returned record doesn't contain password
	ok($meeting->$_ eq $meeting_str_data{$_}, "meeting $_ eq $meeting_str_data{$_}");
    }

    foreach (keys %meeting_int_data) {
	ok($meeting->$_ == $meeting_int_data{$_}, "meeting $_ == $meeting_int_data{$_}");
    }

    my %parameter_str_data = (
	costCenter => 'testing',
	moderatorNotes => 'test moderator notes',
	userNotes => 'test user notes',
	recordingStatus => 'REMOTE',
    );
    
    my %parameter_int_data = (
	raiseHandOnEnter => 1,
	maxTalkers => 3,
	inSessionInvitation => 1
	);

    my $meeting_params = Elive::Entity::MeetingParameters->retrieve([$meeting->meetingId]);

    isa_ok($meeting_params, 'Elive::Entity::MeetingParameters', 'meeting_params');

    $meeting_params->update({%parameter_str_data, %parameter_int_data});

    foreach (keys %parameter_str_data) {
	#
	# returned recxord doesn't contain password
	ok($meeting_params->$_ eq $parameter_str_data{$_}, "meeting parameter $_ eq $parameter_str_data{$_}");
    }

    foreach (keys %parameter_int_data) {
	ok($meeting_params->$_ == $parameter_int_data{$_}, "meeting parameter $_ == $parameter_int_data{$_}");
    }

    my %meeting_server_data = (
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
    );

    #
    # seats are updated via the updateMeeting adapter
    #
    ok($meeting->update({seats => 42}), 'can update number of seats in the meeting');

    my $server_params = Elive::Entity::ServerParameters->retrieve([$meeting->meetingId]);

    isa_ok($server_params, 'Elive::Entity::ServerParameters', 'server_params');

    $server_params->update(\%meeting_server_data);

    foreach (keys %meeting_server_data) {
	ok($server_params->$_ == $meeting_server_data{$_}, "server parameter $_ == $meeting_server_data{$_}");
    }

    ok($server_params->seats == 42, 'server_param - expected number of seats');
    #
    # start to tidy up
    #
    my $meeting_id = $meeting->meetingId;

    lives_ok(sub {$meeting->delete},'meeting deletion');
    #
    # This is an assertion of server behaviour. Just want to verify that
    # meeting deletion cascades to meeting & server parameters
    # are deleted when the meeting is deleted.
    #
    $meeting_params = undef;
    dies_ok( sub {Elive::Entity::MeetingParameters->retrieve([$meeting_id])},
	     'cascaded delete of meeting parameters');

    $server_params = undef;
    dies_ok( sub {Elive::Entity::ServerParameters->retrieve([$meeting_id])},
	     'cascaded delete of server parameters');
}

Elive->disconnect;
