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
    displayName => 'Str',
    userId => 'Str',
    groupingId => 'Str',
    presentationIds => 'Elive::StandardV2::List',
    sessionId => 'Int',
    );

has 'sessionId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('sessionId');

has 'accessType' => (is => 'rw', isa => 'Int',
	       documentation => 'access type; 1:private, 2:restricted, 3:public',
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
		    documentation => 'Whether all non chair participants are granted all permissions',
    );

has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
			   documentation => 'Whether users automaticially raise their hands as they join.',
    );

has 'recordingModeType' => (is => 'rw', isa => 'Int',
			    documentation => 'Recording mode type: 1:manual, 2:automatic, 3:disabled',
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

    my $yesterday = DateTime->today->subtract(days => 1);

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

Returns an L<Elive::StandardV2::SessionTelephony> object for the given session.
This can then be used to get or set the session's telephony characterisitics.

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
    my $params = $class->_freeze({
	sessionId => $session_id,
	presentationIds => $presentation_ids
				 });

    my $som = $connection->call(setSessionPresentation => %$params);

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

    my $params = $class->_freeze({
	sessionId => $session_id,
	multimediaIds => $multimedia_ids
				 });
	
    my $som = $connection->call(setSessionMultimedia => %$params);

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

    $params{sessionId} = $session_id;

    my $user_id = $opt{user_id} || $opt{userId}
	or croak "missing required field: user_id";

    $params{userId} = $user_id,;

    my $display_name = $opt{display_name} || $opt{displayName}
	or croak "missing required field: display_name";

    $params{displayName} = $display_name;

    my $som = $connection->call('buildSessionUrl' => %{ $class->_freeze(\%params) });

    my $results = $class->_get_results(
	$som,
	$connection,
	);

    my $url = @$results && $results->[0];

    return $url;
}

1;
