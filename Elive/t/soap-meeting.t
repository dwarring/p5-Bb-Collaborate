#!perl -T
use warnings; use strict;
use Test::More tests => 31;
use Test::Fatal;

use lib '.';
use t::Elive;

use Carp;

use Elive;
use Elive::Entity::Meeting;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ServerParameters;
use version;

use XML::Simple;

our $t = Test::More->builder;
our $class = 'Elive::Entity::Meeting' ;

our $connection;

SKIP: {

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    my $connection_class = $result{class};
    $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $server_details =  Elive->server_details
	or die "unable to get server details - are all services running?";
    our $version = version->declare( $server_details->version )->numify;
    our $version_11_1_2 = version->declare( '11.1.2' )->numify;
    our $elm_3_5_0_or_higher =  $version >= $version_11_1_2;

    my $meeting_start = time();
    my $meeting_end = $meeting_start + 900;

    $meeting_start .= '000';
    $meeting_end .= '000';

    my %meeting_data = (
	name => 'test meeting, generated by t/soap-meeting.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
	start =>  $meeting_start,
	end => $meeting_end,
	privateMeeting => 1,
    );

    my ($meeting) = $class->insert(\%meeting_data);

    isa_ok($meeting, $class, 'meeting');

    foreach (keys %meeting_data) {
	next if $_ eq 'password';  # the password is not echoed by readback
	is($meeting->$_, $meeting_data{$_}, "meeting $_ as expected");
    }

    my %parameter_data = (
	costCenter => 'testing',
	moderatorNotes => 'test moderator notes. Here are some entities: & > <',
	userNotes => 'test user notes; some more entities: &gt;',
	recordingStatus => 'remote',
	raiseHandOnEnter => 1,
	maxTalkers => 3,
	inSessionInvitation => 1,
	);

    my $meeting_params = Elive::Entity::MeetingParameters->retrieve($meeting->meetingId);

    isa_ok($meeting_params, 'Elive::Entity::MeetingParameters', 'meeting_params');


    $meeting_params->update(\%parameter_data);

    foreach (keys %parameter_data) {
	is($meeting_params->$_, $parameter_data{$_}, "meeting parameter $_ as expected");
    }

    #
    # high level check of our aliasing. updating inSessionInvitations should
    # be equivalent to updating inSessionInvitation
    #
    is( exception {$meeting_params->update({inSessionInvitations => 0})} => undef, "update inSessionInvitations (alias) - lives");
    ok( ! $meeting_params->inSessionInvitation, "update inSessionInvitation via alias - as expected" );
    
    ########################################################################
    # This is a far as we can currently go with a mock connection
    ########################################################################

    skip ($result{reason} || 'skipping live tests', 15)
	if $connection_class->isa('t::Elive::MockConnection');

    my %meeting_server_data = (
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
	seats => 2,
    );

    my $server_params = Elive::Entity::ServerParameters->retrieve($meeting->meetingId);

    isa_ok($server_params, 'Elive::Entity::ServerParameters', 'server_params');

    $server_params->update(\%meeting_server_data);

    foreach (keys %meeting_server_data) {
	is($server_params->$_, $meeting_server_data{$_}, "server parameter $_ as expected");
    }

    do {
	#
	# some cursory checks on jnlp construction. Could be a lot
	# more detailed.
	#
	my $meetingJNLP;
	is( exception {$meetingJNLP = $meeting->buildJNLP(
			  version => '8.0',
			  displayName => 'Elive Test',
			  )} => undef,
		'$meeting->buildJNLP - lives');

	ok($meetingJNLP && !ref($meetingJNLP), 'got meeting JNLP');
	is( exception {XMLin($meetingJNLP)} => undef, 'meeting JNLP is valid XML (XHTML)');
    };

    my $meeting_id = $meeting->meetingId;

    #
    # check that we can access our meeting by user and date range.
    #
    TODO: {
	local $TODO;
	$TODO = 'listUserMeetingsByDate - broken elm 3.0 - 3.4'
	    unless $elm_3_5_0_or_higher;

	my $user_meetings;
	is( exception {
	    $user_meetings
		= Elive::Entity::Meeting->list_user_meetings_by_date(
		[$meeting_data{facilitatorId},
		 $meeting_data{start},
		 $meeting_data{end},
		]
		)
		  } => undef, 'list_user_meetings_by_date(...) - lives');

	isa_ok($user_meetings, 'ARRAY', 'user_meetings');

	ok(@$user_meetings, 'found user meetings by date');
	ok ((grep {$_->meetingId == $meeting_id} @$user_meetings),
	    'meeting is in user_meetings_by_date');
    };

    ok(my $web_url = $meeting->web_url, 'got meeting web_url()');
    #
    # start to tidy up
    #

    is( exception {$meeting->delete} => undef, 'meeting deletion - lives');

    $meeting = undef;

    #
    # The meeting should either have been immediately deleted, or marked as
    # deleted for later garbage collection
    #
    my $deleted_meeting;
    eval {$deleted_meeting = Elive::Entity::Meeting->retrieve($meeting_id)};
    ok($@ || !$deleted_meeting || $deleted_meeting->deleted,
       'meeting deletion enacted');
}

Elive->disconnect;

