package Elive::StandardV3::Session;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV3';

use Scalar::Util;
use Carp;

use Elive::Util;

use Elive::StandardV3::_List;
use Elive::StandardV3::SessionAttendance;
use Elive::StandardV3::SessionTelephony;
use Elive::StandardV3::Multimedia;
use Elive::StandardV3::Presentation;
use Elive::StandardV3::Recording;

=head1 NAME

Elive::StandardV3::Session - Elluminate Session instance class

=head1 DESCRIPTION

This is the main entity class for sessions.

=cut

__PACKAGE__->entity_name('Session');

__PACKAGE__->params(
    displayName => 'Str',
    userId => 'Str',
    groupingId => 'Str',
    presentationId => 'Int',
    multimediaId => 'Int',
    multimediaIds => 'Elive::StandardV3::_List',
    sessionId => 'Int',
    recurrenceCount => 'Int',
    recurrenceDays => 'Int',
    apiCallbackUrl => 'Str',
    );


=head1 PROPERTIES

=head2 sessionId (Int)

Identifier of the session.

=cut

has 'sessionId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('sessionId');

=head2 accessType (Int)

Session access type:

=over 4

=item 1 = I<Private> - This type does not apply to ELM. If you set this to 1, the API will change it to 2.

=item 2 = I<Restricted> - only users specified in the chair or non-chair lists (or guests invited with the email links) may join.

=item 3 = I<Public> - All users within your login group may join.

=back

If you don't specify a value, the default is taken from the C<Restrict Session Access> setting in the Default Session Preferences, These preferences are available through the ELM user interface. For more information, see the online help available from the Elluminate Live! Manager user interface.

=cut

has 'accessType' => (is => 'rw', isa => 'Int',
	       documentation => '1=private (n/a), 2=restricted, 3=public',
    );

=head2 allowInSessionInvites (Bool)

This flag value controls whether or not the chair of this session can send invitations to join the session from within the session.

If you don't specify a value, the default is taken from the C<Enable In-Session Invitations> setting in the Default Session Preferences.

=cut

has 'allowInSessionInvites' => (is => 'rw', isa => 'Bool',
	       documentation => 'allow in-session invitations',
    );

=head2 boundaryTime (Int)

Boundary time. (Defined as the period before the start of a session in which users can join the session. Used by chairs to preload content and by non-chairs who have never joined an Elluminate Live! session before to download the jar files and configure their audio.)

Specified in minutes, to a maximum value of 1440 minutes (24 hours).
If you don't specify a value, the default is taken from the C<Early Session Access Time> setting in the Default Session Preferences.

=cut

has 'boundaryTime' => (is => 'rw', isa => 'Int',
	       documentation => 'boundary time minutes: 0, 15, 30...',
    );

=head2 chairList (Str)

Array of user identifiers from your system that specifies which users may join the Elluminate Live! session as chairpersons.

Each user identifier in the list may be 1 - 64 characters in length, and each identifier is case sensitive. A userId may not appear in both the chair and non-chair lists.

=cut

has 'chairList' => (is => 'rw', isa => 'Elive::StandardV3::_List', coerce => 1,
	       documentation => 'list of chair-persons',
    );

=head2 chairNotes (Str)

Text field that can be used to store notes specific to users with chair role.
1 to 2147483647 characters in length.

=cut

has 'chairNotes' => (is => 'rw', isa => 'Str',
	       documentation => 'chair notes',
    );

=head2 creatorId (Str)

Identifier of the session creator as specified by you in your system.
Case sensitive. 1 - 32 characters in length. May not be updated.

=cut

has 'creatorId' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'creator user id',
    );

=head2 endTime (HiResDate)

End date and time of the session in milliseconds.

=cut

has 'endTime' => (is => 'rw', isa => 'HiResDate', required => 1,
	      documentation => 'session end time');

=head2 groupingList (Str)

Array of unique course identifiers from your system with which to associate this Elluminate Live! session.

Each course identifier may be 1 - 32 characters in length, and each identifier is case sensitive.

=cut

has 'groupingList' => (is => 'rw', isa => 'Elive::StandardV3::_List', coerce => 1,
	       documentation => 'list of courses etc (user defined)',
    );

=head2 sessionName (Str)

The session name. This name will appear in the Elluminate Live! session title
bar. Case insensitive. 1 - 255 characters in length. Must begin with a letter
or digit and may not contain C<E<lt>>, C<&>, '"', C<#>, or C<%>.

=cut

has 'sessionName' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'session name',
    );

=head2 hideParticipantNames (Bool)

This flag value controls whether or not the session participant names are hidden in any session recording that may be made.

If you don't specify a value, the default is taken from the C<Hide Attendee Names> setting in the Default Session Preferences

=cut

has 'hideParticipantNames' => (is => 'rw', isa => 'Bool',
			       documentation => 'Hide Participant Names',
    );

=head2 maxCameras (Int)

Maximum number of simultaneous video cameras to be configured in the Elluminate Live! session at session launch time.

For single server configurations, this value must be between 1 and C<maxAvailableCameras> (as returned from the L<Elive::StandardV3::ServerConfiguration> C<get()> command).

For multiple server configurations, this must be between 1 and versionMaxFilmersLimit for the version you are using (as returned from the L<Elive::StandardV3::ServerVersions> C<get()> command).

If you don't specify a value, the default is taken from the C<Maximum Simultaneous Cameras> setting in the Default Session Preferences.

=cut

has 'maxCameras' => (is => 'rw', isa => 'Int',
		     documentation => 'maximum simultaneous cameras'
    );

=head2 maxTalkers (Int)

Maximum number of simultaneous talkers to be configured in the Elluminate Live! session at session launch time.

For single server configurations, this value must be between 1 and C<maxAvailableTalkers> property (as returned from the L<Elive::StandardV3::ServerConfiguration> C<get()> command).

For multiple server configurations, this must be between 1 and C<versionMaxTalkersLimit> for the version you are using (as returned from the C<Elive::StandardV3::ServerVersions> C<get()> command).

If you don't specify a value, the default is taken from the C<Maximum Simultaneous Talkers> setting in the Default Session Preferences.

=cut

has 'maxTalkers' => (is => 'rw', isa => 'Int',
		     documentation => 'maximum simultaenous talkers'
    );

=head2 mustBeSupervised (Bool)

Permits chairpersons to view all private chat messages in the Elluminate Live! session.
If you don't specify a value, the default is taken from the Early Session Access Time setting in the Default Session Preferences.

=cut

has 'mustBeSupervised' => (is => 'rw', isa => 'Bool',
			   documentation => 'Session number be supervised',
    );

=head2 nonChairList

Comma-separated list of user identifiers from your system that specifies which users may join the Elluminate Live! session as non-chair participants. (That is assuming that openChair is set to false. If C<openChair> is set to true, then all users will be chairpersons.)

Each user identifier in the list may be 1 - 64 characters in length, and each identifier is case sensitive. A userId may not appear in both the chair and non-chair lists.

=cut

has 'nonChairList' => (is => 'rw', isa => 'Elive::StandardV3::_List', coerce => 1,
	       documentation => 'list of participants',
    );

=head2 nonChairNotes (Str)

Text field that can be used to store notes specific to non-chair participants.
1 to 2147483647 characters in length.

=cut

has 'nonChairNotes' => (is => 'rw', isa => 'Str',
	       documentation => 'non chair notes',
    );

=head2 startTime (HiResDate)

Start date and time of the session in milliseconds.

This can be constructed by appending C<000> to a standard unix epoch date.

=cut

has 'startTime' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'session start time');

=head2 openChair (Bool)

All users will join the session as a chairperson in the Elluminate Live! session.

If you don't specify a value, the default is taken from the C<Grant All Permissions on Entry> setting in the Default Session Preferences.

=cut

has 'openChair' => (is => 'rw', isa => 'Bool',
		    documentation => 'Let all users act as chairpersons',
    );

=head2 permissionsOn (Bool)

All users who join the session as non-chairpersons are granted full permissions to session resources such as audio, whiteboard, etc.

If you don't specify a value, the default is taken from the Make Everyone Moderator setting in the Default Session Preferences.

=cut

has 'permissionsOn' => (is => 'rw', isa => 'Bool',
		    documentation => 'Whether all non chair participants are granted all permissions',
    );

=head2 raiseHandOnEnter (Bool)

When users join the Elluminate Live! session, they will automatically raise their hand (this is accompanied by an audible notification).

If you don't specify a value, the default is taken from the Raise Hand on Entry setting in the Default Session Preferences.

=cut

has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
			   documentation => 'Whether users automaticially raise their hands as they join.',
    );

=head2 recordingModeType (Int)

The mode of recording in the Elluminate Live! session:

=over 4

=item C<1> (I<Manual>) - A chairperson must start the recording.

=item C<2> (I<Automatic>) - The recording starts automatically when the session first starts.

=item C<3> (I<Disabled>) - Recording is disabled.

=back

If you don't specify a value, the default is taken from the Session Recording setting in the Default Session Preferences.

=cut

has 'recordingModeType' => (is => 'rw', isa => 'Int',
			    documentation => 'Recording mode type: 1:manual, 2:automatic, 3:disabled',
    );

=head2 reserveSeats (Int)

Number of seats reserved for this session.

If C<Must reserve seats> is enabled for your login group, this number will be
removed from your purchased license limit for the duration of this session.

In addition, this number acts as a cap to the number of users that may join this session, regardless of the number of users in the user lists, or guests invited through the email facility.

If C<Must reserve seats> is disabled, then this parameter is ignored.
Generally, this parameter is not used.

=cut

has 'reserveSeats' => (is => 'rw', isa => 'Int',
		       documentation => 'Number of places to reserve on server',
    );

=head2 secureSignOn (Bool)

This parameter does not apply to ELM.

=cut

has 'secureSignOn' => (is => 'rw', isa => 'Bool',
		       documentation => 'N/A to ELM',
    );

=head2 recordings (Bool)

Whether the session has any recordings.

=cut

has 'recordings' => (is => 'rw', isa => 'Bool',
		       documentation => 'Whether session has any recordings',
    );

=head2 versionId (Int)

This parameter does not apply to ELM.

=cut

has 'versionId' => (is => 'rw', isa => 'Int',
		    documentation => 'Version Id (N/A to ELM)',
    );


=head1 METHODS

=cut

sub _readback_check {
    my ($class, $_updates_ref, $rows, @args) = @_;
    my %updates = %$_updates_ref;
    #
    # cop out of checking start and end times for recurring
    # sessions
    #
    if ($rows && @$rows > 1) {
	delete $updates{startTime};
	delete $updates{endTime};
    }

    return $class->SUPER::_readback_check( \%updates, $rows, @args);
}

=head2 insert

    use Elive::StandardV3;
    use Elive::StandardV3::Session;
    use Elive::Util;

    my $connection = Elive::StandardV3->connect(
                                'http://myserver/mysite',
                                'some_user' => 'some_pass' );

    # Sessions must start and end on the quarter hour.

    my $session_start = Elive::Util::next_quarter_hour();
    my $session_end = Elive::Util::next_quarter_hour( $session_start );

    my %session_data = (
	sessionName   => 'My Demo Session',
	creatorId     => $connection->user,
	startTime     => $session_start . '000',
	endTime       => $session_end . '000',
	openChair     => 1,
	mustBeSupervised => 0,
	permissionsOn => 1,
        nonChairList  => [qw(alice bob)],
	groupingList  => [qw(mechanics sewing)],
    );

    my $session = Elive::StandardV3::Session->insert(\%session_data);

    my $url = $session->session_url( userId => 'bob', displayName => 'Robert');
    print "bob's session link is: $url\n";

A series of sessions can be created using the C<recurrenceCount> and C<recurrenceDays> parameters.

    #
    # create three weekly sessions
    #
    my @sessions = Elive::StandardV3::Session->insert({
                            ...,
                            recurrenceCount => 3,
                            recurrenceDays  => 7,
                        });
=cut

=head2 update

    $session->maxCameras(5);
    $session->hideParticipantNames(0);
    $session->update;

    #
    # ...or...
    #
    $session->update({maxCameras => 5, hideParticipantNames => 0});

Updates a previous created session.

=cut

sub update {
    my ($class, $data, %opt) = @_;

    $opt{command} ||= 'Update'.$class->entity_name;

    return $class->SUPER::update($data, %opt);
}

=head2 retrieve

    my $session = Elive::StandardV3::Session->retrieve( $session_id );

Retrieves a session.

=cut

=head2 list

    #
    # perl code snippet to select sessions in group 'perl_tut_1'
    # created from yesterday onwards.
    #
    my $yesterday_dt = DateTime->today->subtract( days => 1 );
    my $yesterday_msec = $yesterday_dt->epoch . '000';

    my $sessions
           = Elive::StandardV3::Session->list(filter => {
                                               groupingId => 'perl_tut_1',
                                               startTime => $yesterday_msec,
                                              });

    foreach my $session (@$sessions) {

        my $session_id = $session->sessionId;
        my $session_name = $session->sessionName;

        print "found id=$session_id, name=$session_name\n"; 

    }

Returns an array of session objects. You may filter on:

=over 4

=item C<userId> - Matched against C<chairList> and C<nonChairList>

=item C<groupingId> - An Element from the C<groupingList>

=item C<sessionId> - Session identifier

=item C<creatorId> - Session creator

=item C<startTime> - Start of the search date/time range in milliseconds.

=item C<endTime> - End of the search date/time range in milliseconds.

=item C<sessionName> - The session name

=cut

=back
 
=head2 delete

    $session->delete;

Deletes unwanted or completed sessions.

=cut

=head2 telephony

    my $session_telephony = $session->telephony;
    $session_telephony->update({
        chairPhone => '(03) 5999 1234',
        chairPIN   => '6342',
     });

Returns an L<Elive::StandardV3::SessionTelephony> object for the given session.
This can then be used to get or set the session's telephony characterisitics.

=cut

sub telephony {
    my ($self, %opt) = @_;

    return Elive::StandardV3::SessionTelephony->retrieve($self,
							 reuse => 1,
							 connection => $self->connection,
							 %opt,
	);
}

=head2 set_presentation

    $session->set_presentation($presentation);

Aossociates the presentation with a session.

=cut

sub set_presentation {
    my ($class, $presentation_id, %opt) = @_;

    my $session_id = delete $opt{sessionId};
    $session_id ||= $class->sessionId
	if Scalar::Util::blessed($class);

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $params = $class->_freeze({
	sessionId => $session_id,
	presentationId => $presentation_id
				 });

    my $command = $opt{command} || 'SetSessionPresentation';

    my $som = $connection->call($command => %$params);

    my $results = $class->_get_results( $som, $connection );

    my $success = @$results && $results->[0];

    return $success;
}
			      
=head2 set_multimedia

    $session->set_multimedia([$multimedia_1, $multimedia_2]);

Associates a session with Multimedia content.

=cut

sub set_multimedia {
    my ($class, $multimedia_ids, %opt) = @_;

    my $session_id = delete $opt{sessionId};
    $session_id ||= $class->sessionId
	if Scalar::Util::blessed($class);

    for ($multimedia_ids) {
	croak 'usage: $'.(ref($class)||$class).'->set_multimedia(\@multimedia_ids)'
	    unless defined;
	#
	# coerce a single value to an array
	#
	$_ = [$_]
	    if Elive::Util::_reftype($_) ne 'ARRAY';
    }

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $params = $class->_freeze({
	sessionId => $session_id,
	multimediaIds => $multimedia_ids
				 });

    my $command = $opt{command} || 'SetSessionMultimedia';
    my $som = $connection->call($command => %$params);

    my $results = $class->_get_results( $som, $connection );

    my $success = @$results && $results->[0];

    return $success;
}

=head2 list_multimedia

    my $multimedia = $meeting_obj->list_multimedia;

Lists all multimedia associated with the session.

See also L<Elive::StandardV3::Multimedia>.

=cut

sub list_multimedia {
    my ($self, @args) = @_;

    return Elive::StandardV3::Multimedia
        ->list({sessionId => $self->sessionId},
	       connection => $self->connection,
	       @args);
}

=head2 list_presentation

    my $presentation = $meeting_obj->list_presentation;

Lists all presentation associated with the session.

See also L<Elive::StandardV3::Presentation>.

=cut

sub list_presentation {
    my ($self, @args) = @_;

    return Elive::StandardV3::Presentation
        ->list({sessionId => $self->sessionId},
	       connection => $self->connection,
	       @args);
}

=head2 remove_presentation

    my $presentation_list = $session->list_presentation;

    foreach my $presentation_item (@$presentation_list) {
        $session->remove_presentation( $presentation_item );
    }

Disassociate the given presentation item from the session

=cut

sub remove_presentation {
    my $class = shift;
    my $presentation_id = shift;
    my %opt = @_;

   my $session_id = delete $opt{sessionId};
    $session_id ||= $class->sessionId
	if Scalar::Util::blessed($class);

   my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $params = $class->_freeze({
	sessionId => $session_id,
	presentationId => $presentation_id
				 });

    my $command = $opt{command} || 'RemoveSessionPresentation';
    my $som = $connection->call($command => %$params);

    my $results = $class->_get_results( $som, $connection );

    my $success = @$results && $results->[0];

    return $success;

}
			      
=head2 remove_multimedia

    my $multimedia_list = $session->list_multimedia;

    foreach my $multimedia_item (@$multimedia_list) {
        $session->remove_multimedia( $multimedia_item );
    }

Disassociate the given multimedia item from the session

=cut

sub remove_multimedia {
    my $class = shift;
    my $multimedia_id = shift;
    my %opt = @_;

   my $session_id = delete $opt{sessionId};
    $session_id ||= $class->sessionId
	if Scalar::Util::blessed($class);

   my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $params = $class->_freeze({
	sessionId => $session_id,
	multimediaId => $multimedia_id
				 });

    my $command = $opt{command} || 'RemoveSessionMultimedia';
    my $som = $connection->call($command => %$params);

    my $results = $class->_get_results( $som, $connection );

    my $success = @$results && $results->[0];

    return $success;

}
			      
=head2 list_recordings

    my $recordings = $meeting_obj->list_recordings;

Lists all recording associated with the session.

See also L<Elive::StandardV3::Recording>.

=cut

sub list_recordings {
    my ($self, @args) = @_;

    return Elive::StandardV3::Recording
        ->list({sessionId => $self->sessionId},
	       connection => $self->connection,
	       @args);
}

=head2 session_url

    my $session_url = $session->session_url(userId => 'bob');

Returns a URL for the session. This provides authenthicated access for
the given user.

=cut

sub session_url {
    my ($class, %opt) = @_;

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my %params;

    my $session_id = $opt{sessionId};

    $session_id ||= $class->sessionId
	if ref($class);

    croak "unable to determine sessionId"
	unless $session_id;

    $params{sessionId} = $session_id;

    my $user_id = $opt{userId}
	or croak "missing required field: userId";

    $params{userId} = $user_id;

    $params{displayName} = $opt{displayName}
    if defined $opt{displayName};

    my $command = $opt{command} || 'BuildSessionUrl';

    my $som = $connection->call($command => %{ $class->_freeze(\%params) });

    my $results = $class->_get_results( $som, $connection );

    my $url = @$results && $results->[0];

    return $url;
}

=head2 set_api_callback_url

    my $session_url = $session->session_url($url);

This method calls the C< SetApiCallbackUrl> command, which is used to specify a
callback URL that will be notified every time a room closes.

If a session is launched multiple times, there will be multiple rooms
(instances of the session). When each room closes, the callback URL will be
called. If the session is only launched once, the URL will be called once.

=cut

sub set_api_callback_url {
    my ($class, $url, %opt) = @_;

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $session_id = $opt{sessionId};

    $session_id ||= $class->sessionId
	if ref($class);

    croak "unable to determine sessionId"
	unless $session_id;

    my %params;
    $params{sessionId} = $session_id;
    $params{apiCallbackUrl} = $url;

    my $command = $opt{command} || 'SetApiCallbackUrl';

    my $som = $connection->call($command => %{ $class->_freeze(\%params) });

    my $results = $class->_get_results( $som, $connection );

    my $success = @$results && $results->[0];

    return $success;
}

=head2 attendance

    my $yesterday = DateTime->today->subtract(days => 1);

    my $attendance = $session->attendance( $yesterday->epoch.'000' );

Reports on session attendance for a given day. It returns a reference to an array of L<Elive::StandardV3::SessionAttendance> objects.

=cut

sub attendance {
    my ($self, $start_time, %opt) = @_;

    $start_time ||= $self->startTime;

    return Elive::StandardV3::SessionAttendance->list(
	filter=> {
	    sessionId => $self->sessionId,
	    startTime => $start_time,
	},
	connection => $self->connection,
	%opt,
	);
}

1;
