package Elive::StandardV2::Session;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV2';

use Scalar::Util;
use Carp;

use Elive::Util;

use Elive::StandardV2::List;
use Elive::StandardV2::SessionAttendance;
use Elive::StandardV2::SessionTelephony;
use Elive::StandardV2::Presentation;

=head1 NAME

Elive::StandardV2::Session - Elluminate Session instance class

=head1 DESCRIPTION

This is the main entity class for sessions.

=cut

__PACKAGE__->entity_name('Session');

__PACKAGE__->params(
    userId => 'Str',
    groupingId => 'Str',
    );

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

has 'chairList' => (is => 'rw', isa => 'Elive::StandardV2::List', coerce => 1,
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

has 'groupingList' => (is => 'rw', isa => 'Elive::StandardV2::List', coerce => 1,
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

has 'nonChairList' => (is => 'rw', isa => 'Elive::StandardV2::List', coerce => 1,
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

Reports on session attendance for a given day. It returns a reference to an array of L<Elive::StandardV2::SessionAttendance> objects.

=cut

sub attendance {
    my ($self, $start_time, %opt) = @_;

    return Elive::StandardV2::SessionAttendance->list(
	filter=> {
	    sessionId => $self->sessionId,
	    startTime => $start_time,
	},
	connection => $self->connection,
	%opt,
	);
}

=head2 telephony

    my $session_telephony = $session->telephony;
    $session_telephony->update({
        chairPhone => '(03) 5999 1234',
        chairPIN   => '6342',
     });

Returns an Elive::StandardV2::Telephony object for the given session. This can then
be used to get or set the sessions's telephony characterisitics.

=cut

sub telephony {
    my ($self, %opt) = @_;

    return Elive::StandardV2::SessionTelephony->retrieve([$self],
							 reuse => 1,
							 connection => $self->connection,
							 %opt,
	);
}

=head2 set_presentation

    $session->set_presentation([$presentation_1, $presentation_2]);

Associates Presentations with Sessions.

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
	'setSessionPresentation',
	sessionId => Elive::Util::_freeze($session_id, 'Int'),
	presentationIds => Elive::Util::_freeze($presentation_ids, 'Elive::StandardV2::List'),
	);

    my $results = $class->_get_results(
	$som,
	$connection,
	);

    my $success = @$results && $results->[0];

    return $success;
}
			      
=head2 set_multimedia

    $session->set_multimedia([$multimedia_1, $multimedia_2]);

Associates Multimedias with Sessions.

=cut

sub set_multimedia {
    my ($class, $multimedia_ids, %opt) = @_;

    my $session_id = delete $opt{sessionId};
    $session_id ||= $class->sessionId
	if Scalar::Util::blessed($class);

    croak 'usage: $'.(ref($class)||$class).'->set_multimedia(\@multimedia_ids)'
	unless Scalar::Util::reftype( $multimedia_ids ) eq 'ARRAY';

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $som = $connection->call(
	'setSessionMultimedia',
	sessionId => Elive::Util::_freeze($session_id, 'Int'),
	multimediaIds => Elive::Util::_freeze($multimedia_ids, 'Elive::StandardV2::List'),
	);

    my $results = $class->_get_results(
	$som,
	$connection,
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

    my $som = $connection->call('buildSessionUrl' => %params);

    my $results = $class->_get_results(
	$som,
	$connection,
	);

    my $url = @$results && $results->[0];

    return $url;
}

1;
