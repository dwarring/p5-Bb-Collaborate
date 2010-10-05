#!perl
use warnings; use strict;
use Test::More tests => 41;
use Test::Exception;
use Test::Builder;
use version;

use lib '.';
use t::Elive;

use Carp;

use Elive;
use Elive::Entity::Meeting;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ServerParameters;
use Elive::Entity::ParticipantList;

use XML::Simple;

our $t = Test::Builder->new;
our $class = 'Elive::Entity::Meeting' ;

our $connection;

SKIP: {

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    my $connection_class = $result{class};
    $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $server_version = $connection->server_details->version;
    my $server_version_num = version->new($server_version)->numify;

    my %meeting_str_data = (
	name => 'test meeting, generated by t/22-soap-meeting.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
    );

    my $meeting_start = time();
    my $meeting_end = $meeting_start + 900;

    $meeting_start .= '000';
    $meeting_end .= '000';

    my %meeting_int_data = (
	start =>  $meeting_start,
	end => $meeting_end,
	privateMeeting => 1,
    );

    if (1) {
	$t->skip("can't modify restrictedMeeting property (known problem)");
    }
    else {
	$meeting_int_data{restrictedMeeting} = 1;
    }

    my ($meeting) = $class->insert({%meeting_int_data, %meeting_str_data});

    isa_ok($meeting, $class, 'meeting');

    foreach ('name') {
	#
	# returned record doesn't contain password
	is($meeting->$_, $meeting_str_data{$_}, "meeting $_ as expected");
    }

    foreach (keys %meeting_int_data) {
	is($meeting->$_, $meeting_int_data{$_}, "meeting $_ as expected");
    }

    my %parameter_str_data = (
	costCenter => 'testing',
	moderatorNotes => 'test moderator notes. Here are some entities: & > <',
	userNotes => 'test user notes; some more entities: &gt;',
	recordingStatus => 'remote',
    );
    
    my %parameter_int_data = (
	raiseHandOnEnter => 1,
	maxTalkers => 3,
	);

    my $meeting_params = Elive::Entity::MeetingParameters->retrieve([$meeting->meetingId]);

    isa_ok($meeting_params, 'Elive::Entity::MeetingParameters', 'meeting_params');

    $meeting_params->update({%parameter_str_data, %parameter_int_data});

    foreach (keys %parameter_str_data) {
	#
	# returned record doesn't contain password
	is($meeting_params->$_, $parameter_str_data{$_}, "meeting parameter $_ as expected");
    }

    foreach (keys %parameter_int_data) {
	is($meeting_params->$_, $parameter_int_data{$_}, "meeting parameter $_ as expected");
    }

    ########################################################################
    # This is a far as we can currently go with a mock connection
    ########################################################################

    skip ($result{reason} || 'skipping live tests', 28)
	if $connection_class->isa('t::Elive::MockConnection');

    my %meeting_server_data = (
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
    );

    #
    # seats are updated via the updateMeeting adapter
    #
    ok($meeting->update({seats => 2}), 'can update number of seats in the meeting');

    my $server_params = Elive::Entity::ServerParameters->retrieve([$meeting->meetingId]);

    isa_ok($server_params, 'Elive::Entity::ServerParameters', 'server_params');

    $server_params->update(\%meeting_server_data);

    foreach (keys %meeting_server_data) {
	is($server_params->$_, $meeting_server_data{$_}, "server parameter $_ as expected");
    }

    ok($server_params->seats == 2, 'server_param - expected number of seats');

    my $participants_deep_ref = [{user => Elive->login->userId,
				  role => 0}];
    #
    # NB. It's not neccessary to insert prior to update, but since we allow it
    lives_ok(
	sub {my $_p = Elive::Entity::ParticipantList->insert(
		 {meetingId => $meeting->meetingId,
		  participants => $participants_deep_ref});
	     diag ("participants=".$_p->participants->stringify);
	},
	'insert of participant deep list - lives');

    my $participant_list = Elive::Entity::ParticipantList->retrieve([$meeting->meetingId]);

    isa_ok($participant_list, 'Elive::Entity::ParticipantList', 'server_params');
    is($participant_list->participants->stringify, Elive->login->userId.'=0',
       'participant deep list - set correctly');

    $participant_list->update({participants => [Elive->login->userId.'=1']});

    is($participant_list->participants->stringify, Elive->login->userId.'=1',
       'participant shallow list - set correctly');

    $participant_list->update({participants => Elive->login->userId.'=2'});

    diag ("participants=".$participant_list->participants->stringify);

    is($participant_list->participants->stringify, Elive->login->userId.'=2',
       'participant string list - set correctly');

    ok($meeting->is_participant( Elive->login), 'is_participant($moderator)');
    ok($meeting->is_moderator( Elive->login), 'is_moderator($moderator)');

    my $gate_crasher = 'gate_crasher_'.t::Elive::generate_id();

    ok(!$meeting->is_participant( $gate_crasher ), '!is_participant($gate_crasher)');
    ok(!$meeting->is_moderator( $gate_crasher ), '!is_moderator($gate_crasher)');

    lives_ok(sub {$participant_list->update({participants => []})},
	     'clearing participants - lives');

    my $p = $participant_list->participants;

    #
    # check our reset policy. Updating/creating an empty participant
    # list is effectively the same as a reset. Ie, we end up with
    # the facilitator as the sole participant, with a role of moderator (2).
    #

    is(@$p, 1, 'participant_list reset - single participant');

    is($p->[0]->user && $p->[0]->user->userId, $meeting->facilitatorId,
       'participant_list reset - single participant is the facilitator');

    is($p->[0]->role && $p->[0]->role->roleId, 2,
       'participant_list reset - single participant has moderator role');

    do {
	#
	# some cursory checks on jnlp construction. Could be a lot
	# more detailed.
	#
	my $meetingJNLP;
	lives_ok(sub {$meetingJNLP = $meeting->buildJNLP(
			  version => '8.0',
			  displayName => 'Elive Test',
			  )},
		'$meeting->buildJNLP - lives');

	ok($meetingJNLP && !ref($meetingJNLP), 'got meeting JNLP');
	lives_ok(sub {XMLin($meetingJNLP)}, 'JNLP is valid XML (XHTML)');
    };

    #
    # check that we can access our meeting by user and date range.
    #

    my $user_meetings = Elive::Entity::Meeting->list_user_meetings_by_date(
	[$meeting_str_data{facilitatorId},
	 $meeting_int_data{start},
	 $meeting_int_data{end},
	 ]
	);

    isa_ok($user_meetings, 'ARRAY', 'user_meetings');

    my $meeting_id = $meeting->meetingId;

    ok(@$user_meetings, 'found user meetings by date');
    ok ((grep {$_->meetingId == $meeting_id} @$user_meetings),
	'meeting is in user_meetings_by_date');

    ok(my $web_url = $meeting->web_url, 'got meeting web_url()');
    #
    # start to tidy up
    #

    lives_ok(sub {$meeting->delete},'meeting deletion');
    #
    # This is an assertion of server behaviour. Just want to verify that
    # meeting deletion cascades. I.e. meeting & server parameters are deleted
    # when the meeting is deleted.
    #
    $meeting_params = undef;

    $meeting = undef;

    my $deleted_meeting;
    eval {$deleted_meeting = Elive::Entity::Meeting->retrieve([$meeting_id])};
    #
    # Change in policy with elluminate 9.5.1. Deleted meetings remain
    # retrievable, they just have the deleted flag set
    #
    ok($@ || ($deleted_meeting && $deleted_meeting->deleted),
       'cascaded delete of meeting parameters');
}

Elive->disconnect;

