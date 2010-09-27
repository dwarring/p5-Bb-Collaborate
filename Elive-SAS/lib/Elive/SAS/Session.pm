package Elive::SAS::Session;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

use Scalar::Util;
use Carp;

use Elive::Util;

use Elive::SAS::List;
use Elive::SAS::SessionAttendance;
use Elive::SAS::Presentation;

=head1 NAME

Elive::SAS::Session - Elluminate Session instance class

=head1 DESCRIPTION

This is the main entity class for sessions.

=cut

__PACKAGE__->entity_name('Session');

has 'sessionId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('sessionId');

has 'accessType' => (is => 'rw', isa => 'Int',
	       documentation => 'creator user id',
    );

has 'allowInSessionInvites' => (is => 'rw', isa => 'Bool',
	       documentation => 'allow in-session invitations',
    );

has 'boundaryTime' => (is => 'rw', isa => 'Int',
	       documentation => 'boundary time minutes: 0, 15, 30...',
    );

has 'chairList' => (is => 'rw', isa => 'Elive::SAS::List', coerce => 1,
	       documentation => 'list of chair-persons (comma separated)',
    );

has 'chairNotes' => (is => 'rw', isa => 'Str',
	       documentation => 'chair notes',
    );

has 'creatorId' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'creator user id',
    );

has 'endTime' => (is => 'rw', isa => 'HiResDate', required => 1,
	      documentation => 'session end time');

has 'groupingList' => (is => 'rw', isa => 'Elive::SAS::List', coerce => 1,
	       documentation => 'list of courses etc (user defined)',
    );

has 'sessionName' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'session name',
    );

has 'hideParticipantNames' => (is => 'rw', isa => 'Bool',
			       documentation => 'Hide Participant Names',
    );

has 'maxCameras' => (is => 'rw', isa => 'Int',
		     documentation => 'maximum simultaneous cameras'
    );

has 'maxTalkers' => (is => 'rw', isa => 'Int',
		     documentation => 'maximum simultaenous talkers'
    );

has 'mustBeSupervised' => (is => 'rw', isa => 'Bool',
			   documentation => 'Session number be supervised',
    );

has 'nonChairList' => (is => 'rw', isa => 'Elive::SAS::List', coerce => 1,
	       documentation => 'list of participants (comma separated)',
    );

has 'nonChairNotes' => (is => 'rw', isa => 'Str',
	       documentation => 'non chair notes',
    );

has 'startTime' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'session start time');

has 'openChair' => (is => 'rw', isa => 'Bool',
		    documentation => 'Let all users act as chairpersons',
    );

has 'permissionsOn' => (is => 'rw', isa => 'Bool',
		    documentation => 'Whether all non chair participcants are granted all permissions',
    );

has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
			   documentation => 'Whether users automaticially raise their hands as they join.',
    );

has 'recordingModeType' => (is => 'rw', isa => 'Int',
			    documentation => '0, 1, 2',
    );

has 'reserveSeats' => (is => 'rw', isa => 'Int',
		       documentation => 'Number of places to reserve on server',
    );

has 'secureSignOn' => (is => 'rw', isa => 'Bool',
		       documentation => 'N/A to ELM',
    );

has 'recordings' => (is => 'rw', isa => 'Bool',
		       documentation => 'Whether session has any recordings',
    );

has 'versionId' => (is => 'rw', isa => 'Int',
		    documentation => 'ELM version Id (E.g. 1001 == 10.0.1)',
    );


=head1 METHODS

=cut

=head2 attendance

    my $today = DateTime->yesterday->subtract(days => 1);

    my $attendance = $session->attendance( $yesterday->epoch.'000' );

Reports on session attendance for a given day. It returns a reference to an array of Elive::SAS::SessionAttendance objects.

=cut

sub attendance {
    my ($self, $start_time, %opt) = @_;

    return Elive::SAS::SessionAttendance->list([$self, $start_time]);
}

=head2 set_presentation

Sets the list of presentation ids for a given session

=cut

sub set_presentation {
    my ($class, $presentation_ids, %opt) = @_;

    my $session_id = delete $opt{sessionId};
    $session_id ||= $class->sessionId
	if Scalar::Util::blessed($class);

    croak 'usage: $'.(ref($class)||$class).'->set_presentation(\@presentation_ids)'
	unless Scalar::Util::reftype( $presentation_ids ) eq 'ARRAY';

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $som = $connection->call(
	$class->check_adapter( 'setSessionPresentation'),
	sessionId => Elive::Util::_freeze($session_id, 'Int'),
	presentationIds => Elive::Util::_freeze($presentation_ids, 'Elive::SAS::List'),
	);

    my $results = $class->_get_results(
	$som,
	);

    my $success = @$results && $results->[0];

    return $success;
}
			      
=head2 session_url

    my $session_url = $session->session_url(user_id => 'bob');

Returns a URL for the session. This provides authenthicated access for
the given user.

=cut

sub session_url {
    my ($class, %opt) = @_;

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my %params;

    my $session_id = $opt{session_id} || $opt{sessionId};

    $session_id ||= $class->sessionId
	if ref($class);

    croak "unable to determine session_id"
	unless $session_id;

    $params{sessionId} = Elive::Util::_freeze($session_id, 'Int');

    my $user_id = $opt{user_id} || $opt{userId}
	or croak "missing required field: user_id";

    $params{userId} = Elive::Util::_freeze($user_id, 'Str');

    my $display_name = $opt{display_name} || $opt{displayName}
	or croak "missing required field: display_name";

    $params{displayName} = Elive::Util::_freeze($display_name, 'Str');

    my $som = $connection->call(
	$class->check_adapter('buildSessionUrl'),
	%params,
	);

    my $results = $class->_get_results(
	$som,
	);

    my $url = @$results && $results->[0];

    return $url;
}

1;
