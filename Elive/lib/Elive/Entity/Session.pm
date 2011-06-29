package Elive::Entity::Session;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Carp;

extends 'Elive::Entity';

use Elive::Entity::Meeting;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ServerParameters;
use Elive::Entity::ParticipantList;
use Elive::Entity::Participants;
use Elive::Array;

=head1 NAME

Elive::Entity::Session - Session insert/update via ELM 3.x (TRIAL)

=head1 DESCRIPTION

Elive::Entity::Session is under construction as a likely successor to
L<Elive::View::Session>. It implements the C<createSession> and
C<updateSession> commands, introduced with Elluminate 3.0.

=cut

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');

has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');
__PACKAGE__->_alias(meetingId => 'id');
__PACKAGE__->_alias(sessionId => 'id');

__PACKAGE__->params(
    preloadIds => 'Elive::Entity::Preloads',
    invitedParticipantsList => 'Elive::Array',
    invitedModerators => 'Elive::Array',
    invitedGuests => 'Elive::Array',

    until                        => 'HiResDate',
    repeatEvery                  => 'Int',
    repeatSessionInterval        => 'Int',
    repeatSessionMonthlyInterval => 'Int',
    repeatSessionMonthlyDay      => 'Int',

    sundaySessionIndicator    => 'Bool',
    mondaySessionIndicator    => 'Bool',
    tuesdaySessionIndicator   => 'Bool',
    wednesdaySessionIndicator => 'Bool',
    thursdaySessionIndicator  => 'Bool',
    fridaySessionIndicator    => 'Bool',
    saturdaySessionIndicator  => 'Bool',
    );

__PACKAGE__->mk_classdata(_delegates => {
    meeting => 'Elive::Entity::Meeting',
    meetingParameters => 'Elive::Entity::MeetingParameters',
    serverParameters => 'Elive::Entity::ServerParameters',
    participantList => 'Elive::Entity::ParticipantList',
});

sub _delegate {
    my $pkg = shift;

    our %handled = (meetingId => 1, url => 1);
    my $delegates = $pkg->_delegates;

    foreach my $prop (sort keys %$delegates) {
	my $class = $delegates->{$prop};
	my $aliases = $class->_get_aliases;
	my @delegates = grep {!$handled{$_}++} ($class->properties, $class->derivable, sort keys %$aliases);
	push (@delegates, qw{buildJNLP check_preload add_preload remove_preload is_participant is_moderator list_preloads list_recordings})
	    if $prop eq 'meeting';
	has $prop
	    => (is => 'rw', isa => $class, coerce => 1,
		handles => \@delegates,
		lazy => 1,
		default => sub {$class->retrieve($_[0]->id, reuse => 1, connection => $_[0]->connection)},
	    );
    }
}

__PACKAGE__->_delegate;

## ELM 3.x mappings follow

__PACKAGE__->_alias(allPermissionsMeeting => 'fullPermissions', freeze => 1);

__PACKAGE__->_alias(boundaryTime => 'boundaryMinutes', freeze => 1);

__PACKAGE__->_alias(enableTeleconferencing => 'enableTelephony', freeze => 1);

__PACKAGE__->_alias(facilitator => 'facilitatorId', freeze => 1);

__PACKAGE__->_alias(MaxVideoWindows => 'VideoWindow', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferenceAddress => 'moderatorTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferencePIN => 'moderatorTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(participantTeleconferenceAddress => 'participantTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(participantTeleconferencePIN => 'participantTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(private => 'privateMeeting', freeze => 1);

__PACKAGE__->_alias(reservedSeatCount => 'seats', freeze => 1);

__PACKAGE__->_alias(restrictParticipants => 'restrictedMeeting', freeze => 1);


__PACKAGE__->_alias(supervisedMeeting => 'supervised', freeze => 1);

__PACKAGE__->_alias(sessionServerTeleconferenceType => 'telephonyType', freeze => 1);

__PACKAGE__->_alias(serverTeleconferenceAddress => 'serverTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(serverTeleconferencePIN => 'serverTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(add_preload => 'preloadIds');

sub _alias {
    my ($entity_class, $from, $to, %opt) = @_;

    $from = lcfirst($from);
    $to = lcfirst($to);

    die 'usage: $entity_class->_alias(alias, prop, %opts)'
	unless ($entity_class

		&& $from && !ref($from)
		&& $to && !ref($to));

    my $aliases = $entity_class->_get_aliases;

    #
    # Set our entity name. Register it in our parent
    #
    die "$entity_class: attempted redefinition of alias: $from"
	if $aliases->{$from};

    die "$entity_class: can't alias $from it's already a property!"
	if $entity_class->property_types->{$from};

# get this test working
##    die "$entity_class: attempt to alias $from to non-existant property $to - check spelling and declaration order"
##	unless $entity_class->property_types->{$to};

    $opt{to} = $to;
    $aliases->{$from} = \%opt;

    return \%opt;
}

sub _data_owned_by {
    my $class = shift;
    my $delegate_class = shift;
    my @props = @_;

    my %owns = (%{ $delegate_class->property_types },
		%{ $delegate_class->_aliases },
		$delegate_class->params);

    return grep { exists $owns{$_} } @props;
}

sub set {
    my $self = shift;
    my %data = @_;

    my $delegates = $self->_delegates;

    foreach my $delegate (sort keys %$delegates) {

	my $delegate_class = $delegates->{$delegate};
	my @delegate_props = $self->_data_owned_by($delegate_class => sort keys %data);
	my %delegate_data =  map {$_ => delete $data{$_}} @delegate_props;

	$self->$delegate->set( %delegate_data );
    }

    carp 'unknown session attributes '.join(' ', sort keys %data).'. expected: '.join(' ', sort $self->properties)
	if keys %data;

    return $self;
}

sub _readback_check {
    my ($class, $_updates_ref, $rows, @args) = @_;
    my %updates = %$_updates_ref;

    $class->_canonicalize_properties( \%updates );
    my $id = $updates{id};

    my $delegates = $class->_delegates;

    foreach my $delegate (sort keys %$delegates) {
	my $delegate_class = $delegates->{$delegate};

	my %delegated_updates;
	foreach( $class->_data_owned_by($delegate_class => %updates) ){
	    $delegated_updates{$_} = delete $updates{$_};
	}

	$delegated_updates{meetingId} = $id if $id;

	foreach my $row (@$rows) {
	    $delegate_class
		->_readback_check(\%delegated_updates, [$row->{$delegate}], @args);
	}
    }

    return $class->SUPER::_readback_check(\%updates, $rows, @args);
}

sub _freeze {
    my $class = shift;
    my %data = %{ shift() };
    my %opts = @_;

    my $delegates = $class->_delegates;

    my %frozen = map {
	my $delegate = $_;
	my $delegate_class = $delegates->{$delegate};
	my @delegate_props = $class->_data_owned_by($delegate_class => sort keys %data);

	#
	# accept flattened or unflattened data: eg $data{meeting}{start} or $data{start}

	my %delegate_data = (
	    %{ $data{$delegate} || {}},
	    map {$_ => delete $data{$_}} @delegate_props
	    );

	%{ $delegate_class->_freeze (\%delegate_data, canonical => 1) };
    } (sort keys %$delegates);

    $class->_freeze_participants( \%frozen );
    #
    # pass any left-overs to superclass for resolution.
    #
    my $params_etc = $class->SUPER::_freeze(\%data);
    foreach (sort keys %$params_etc) {
	$frozen{$_} = $params_etc->{$_} unless defined $frozen{$_};
    }

    $class->__apply_freeze_aliases( \%frozen )
	unless $opts{canonical};

    # todo lots more tidying and construction

    return \%frozen;
}

sub _freeze_participants {
    my $class = shift;
    my $data = shift || {};
    #
    # collate invited guests, moderators and regular participants
    #
    my $raw = delete $data->{participants};
    my $participants = Elive::Entity::Participants->new( $raw );

    ($data->{invitedGuests},
     $data->{invitedModerators},
     $data->{invitedParticipantsList})
	= $participants->tidied();

    return $data
}

sub _unpack_as_list {
    my $class = shift;
    my $data = shift;

    my $results_list = $class->SUPER::_unpack_as_list($data);

    my %results ;
    @results{qw{meeting serverParameters meetingParameters participantList}} = @$results_list;

    $results{Id} = $results{meeting}{MeetingAdapter}{Id};

    # todo: more checking, recurring meetings
    return [\%results]
}

=head2 insert

Creates a new session on an Elluminate server, using the C<createSession> command.

    use Elive::Entity::Session;
    use Elive::Entity::Preload;

    my $session_start = time();
    my $session_end = $session_start + 900;

    $session_start .= '000';
    $session_end .= '000';

    my $preload = Elive::Entity::Preload->upload('c:\\Documents\intro.wbd');

    my %session_data = (
	name => 'An example session',
	facilitatorId => Elive->login->userId,
	password => 'secret',
	start =>  $session_start,
	end => $session_end,
	privateMeeting => 1,
	recordingStatus => 'remote',
	raiseHandOnEnter => 1,
	maxTalkers => 2,
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
	seats => 10,
        participants => [
            -moderators => [qw(alice bob)],
            -others => '*staff_group'
         ],
        add_preload => $preload,
    );

    my $session = Elive::Entity::Session->insert( \%session_data );

=cut

sub insert {
    my $class = shift;
    my %data = %{ shift() };
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection
	or die "not connected";

    my $participants = Elive::Entity::Participants->new( $data{participants} );

    my $facilitatorId = $data{facilitatorId} || $connection->login->userId;
    $participants->add(-moderators => $facilitatorId);

    $data{participants} = $participants->tidied;

    # todo - recurrring meetings, telephony

    die "recurring meetings not supported"
	if $data{recurrenceCount} || $data{recurrenceDays};

    return $class->SUPER::insert( \%data, command => 'createSession', %opt );
}

=head2 is_changed

     my $session = Elive::Entity::Session->retrieve( $session_id);
     #
     # ..then later on
     #
     $session->seats( $session->seats + 5);
     @changed = $session->is_changed;
     #
     # @changed will contained 'seats', plus any other unsaved updates.
     #

Returns a list of properties that have unsaved changes. To avoid warnings, you
will either need to call C<update> on the object to save the changes, or
C<revert> to discard the changes.

=cut

sub is_changed {
    my $self = shift;

    my $delegates = $self->_delegates;

    return map {$self->{$_}? $self->$_->is_changed: ()} (sort keys %$delegates)
}

=head2 revert

    $session->revert('seats'); # revert just the 'seats' property
    $session->revert();        # revert everything

Reverts unsaved updates.

=cut

sub revert {
    my $self = shift;

    my $delegates = $self->_delegates;

    for (sort keys %$delegates) {
	$self->$_->revert if $self->{$_};
    }

    return $self;
}

=head2 update

    $session->update({ boundaryTime => 15});

    # ...or...

    $session->boundaryTime(15);
    $session->update;

Updates session properties

=cut

sub update {
    my $self = shift;
    my %update_data = %{ shift() || {} };
    my %opt = @_;

    my $changed = $opt{changed} || [$ self->is_changed];

    if (@$changed || keys %update_data) {
	#
	# Early ELM 3.x has a habit of wiping defaults we're better off to
	# rewrite the whole record
	#
	my @all_props =  map {$_->properties} values %{$self->_delegates};
		       
	$changed = [ grep {$_ ne 'meetingId'} @all_props ];

	my $connection = $opt{connection} || $self->connection;

	my $facilitatorId = $update_data{facilitatorId}
	|| $self->facilitatorId
	|| $connection->login->userId;

	my $participants = $update_data{participants}
	|| $self->participants;

	$participants = Elive::Entity::Participants->new( $participants )
	    unless Scalar::Util::blessed( $participants );

	$participants->add(-moderators => $facilitatorId);

	$update_data{participants} = $participants->tidied;

	return $self->SUPER::update( \%update_data, %opt, changed => $changed );
    }

    return $self; # nothing to update
}

=head2 retrieve

Retrieves a session for the given session id.

    Elive::Entity::Session->retrieve( $session_id );

=cut

sub retrieve {
    my $class = shift;
    my $id = shift;
    my %opt = @_;
    ($id) = @$id if ref($id);

    my $id_string = Elive::Util::string($id);
    die "nothing to retrieve" unless $id_string;

    my $self = $class->new({id => $id_string});

    $self->_db_data( $class->new({id => $id_string}) );

    for ($opt{connection}) {
	$self->connection($_) if $_;
    }

    return $self;
}

=head2 list

List all sessions that match a given criteria:

    my $sessions = Elive::Entity::Session->list( filter => "(name like '*Sample*')" );

=cut

sub list {
    my $class = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection
	or die "not connected";
    my $meetings = Elive::Entity::Meeting->list(%opt);

    my @sessions = map {
	my $meeting = $_;

	my $self = bless {id => $meeting->meetingId}, $class;
	$self->meeting($meeting);
	$self->connection($connection);

	$self;
    } @$meetings;

    return \@sessions;
}

=head2 delete

Deletes a completed or unwanted session from the Elluminate server.

    my $session = Elive::Entity::Session->retrieve( $session_id );
    $session->delete;

=cut

sub delete {
    my $self = shift;
    my %opt = @_;

    $self->meeting->delete;
    $self->_deleted(1);

    my $delegates = $self->_delegates;

    foreach my $delegate (sort keys %$delegates) {
	$self->$delegate->_deleted(1) if $self->{$delegate};
    }

    return 1;
}

=head1 Working with Participants

=head2 Constructing Participant Lists

A simple input list of participants might look like:

    @participants = (qw{alice bob, *perl_prog_tut_1});

By default, all users/groups/guest in the list are added as unprivileged regular participants.

The list can be interspersed with C<-moderators> and C<-others> markers
to indicate moderators and regular users.

    @participants = (-moderators => qw(alice bob),
                     -others => '*perl_prog_tut_1');

Each participant in the list can be one of several things:

=over 4

=item * A user-id string, in the format '<userId>'

=item * A pre-fetched user object of type Elive::Entity::User

=item * A group-id string, in the format '*<groupId>'

=item * A pre-fetched group object of type Elive::Entity::Group

=item * An invited guest, in the format 'Display Name(loginName)'

=back

Unless you're using LDAP, you're likely to have to look-up users and groups
to resolve login names and group names:

    my $alice = Elive::Entity::User->get_by_loginName('alice');
    my $bob = Elive::Entity::User->get_by_loginName('bob');
    my $tut_group = Elive::Entity::Group->list(filter => "groupName = 'Perl Tutorial Group 1'");

    my @participants = (-moderators => [$alice, $bob],
                        -others => [@$tut_group],
                       );

Then, you just need to pass the list in when you create or update the session:

     Elive::Entity::Session->create({
                     # ... other options
                     participants => \@participants
                    });

You can also fully construct the participant list.

    use Elive::Entity::Participants;
    my $participants_obj = Elive::Entity::Participants->new(\@participants);

     Elive::Entity::Session->create({
                     # ... other options
                     participants => $participants_obj,
                    });

=head2 Managing Participant Lists

Participant lists are returned an arrays of elements of type
L<Elive::Entity::Participant>. Each participant contains one of:

=over 4

=item type 0 (L<Elive::Entity::User>)

=item type 1 (L<Elive::Entity::Group>), or

=item type 2 (L<Elive::Entity::Invited::Guest>)

=back

These are dereferenced via the C<user>, C<group> or C<guest> methods.For
example, to print the list of participants for a session:

    my $session = Elive::Entity::Session->retrieve($session_id);
    my $participants = $session->participants;

    foreach (@$participants) {
	my $type = $_->type;
	my $str;

	if (! $type)  {
	    my $user = $_->user;
	    my $loginName = $user->loginName;
	    my $email = $user->email;

            print 'user: '.$loginName;
	    print ' <'.$email.'>'
		if $email;
	}
	elsif ($type == 1) {
	    my $group = $_->group;
	    my $id = $group->groupId;
	    my $name = $group->name;

	    print 'group: *'.$id;
	    print ' <'.$name.'>'
		if $name;
	}
	elsif ($type == 2) {
	    my $guest = $_->guest;
	    my $loginName = $guest->loginName;
	    my $displayName = $guest->displayName;

	    print 'guest: '.$displayName;
	    print ' ('.$loginName.')'
		if $loginName;
	}
	else {
	    die "unknown participant type $type"; # elm 4.x? ;-)
	}
        print "\n";
    }

You may modify this list in any way, then update the session it belongs to:

    $participants->add( -moderators => 'trev');  # add 'trev' as a moderator

    $session->update({participants => $participants});

=head1 Working with Preloads

Preloads may be both uploaded from the client or server:

    # 1. upload a local file
    my $preload1 = Elive::Entity::Preload->upload('c:\\Documents\slide1.wbd');

    # 2. stream it ourselves
    open ( my $fh, '<', 'c:\\Documents\slide2.wbd')
	or die "unable to open preload file $!";
    my $content = do {local $/; $fh->binmode; <$fh>};
    close $fh;

    my $preload2 = Elive::Entity::Preload->upload(
                     name => 'slide2.wbd',
                     data => $content,
                   );

    # 3. import a file on the Elluminate Live! server
    my $preload3 = Elive::Entity::Preload
         ->import_from_server('/home/uploads/slide3.wbd');

These can then be added to sessions in a number of ways:

    # 1. at session creation
    my $session = Elive::Entity->Session->create({
                           # ...
                           add_preload => $preload1,
                        });

    # 2. when updating a session
    $session->update({add_preload => $preload2});

    # 3. via the add_preload() method
    $session->add_preload( $preload3 );

A single preload can be shared between sessions:

    $session1->add_preload( $preload );
    $session2->add_preload( $preload );

Attempt to add the same preload to a session more than once is considered an
error. The C<check_preload> method might help here>

    $session->add_preload( $preload )
        unless $session->check_preload( $preload );

Preloads are not automatically deleted when you delete session, if you want to
delete them, you can do this yourself:

    my $preloads = $session->list_preloads;
    $session->delete;
    $_->delete for (@$preloads);

But you'd only want to delete the preload if it's not being shared with other
active sessions!

Please see also L<Elive::Entity::Preload>.

=head1 Providing access to Sessions (session JNLPs)

If a user has been registered as a meeting participant, either by being
directly assigned as a participant or by being a member of a group, you
can then create a JNLP for access to the meeting.

    my $user_jnlp = $session->buildJNLP(user => $username);

There's a slightly different format for guests:

    my $guest_jnlp = $session->buildJNLP(userName => $guest_username,
                                         displayName => $guest_display_name);

Unlike registered users, guests do not need to be registered as a session
participant for you to add them as a guest.

For more information, please see L<Elive::Entity::Meeting>.

=head1 Working with recordings (recording JNLPs)

A session can be associated with multiple recording segments. A segment is
created each time recording is stopped an restarted, or when all participants
entirely vacate the session. This can happen multiple times for long running
sessions.

The recordings seem to generally become available within a few minutes, without
any need to close or exit the session.

my $recordings = $session->list_records;

if (@$recordings) {
   # provide access to the first recording
   my $recording_jnlp = $recordings[0]->buildJNLP(userId => $username);
}

Also note that recordings are not deleted, when you delete sessions. If you
want to delete associated recordings when you delete sessions:

   my $recordings = $session->recordings;
    $session->delete;
    $_->delete for (@$recordings);

However it is often customary to keep recordings for an extended period of
time - they will remain accessable from the C<Recordings> web page on your
Elluminate Live! web server.

For more information, please see L<Elive::Entity::Recording>.

=head1 Session Property Reference

Here's an alphabetical list of all available session properties:

=head2 adapter (String)

This is a read only property. This property is read-only and should always have the value C<default> for sessions created via L<Elive::Entity::Session>.

=head2 allModerators (Bool)

All participants can moderate.

=head2 boundaryMinutes (Int)

Session boundary time (minutes).

=head2 costCenter (Str)

User defined cost center.

=head2 deleted (Bool)

True if the session has been deleted.

=head2 enableTelephony (Bool)

Telephony is enabled

=head2 end (HiResDate)

The session end time (milliseconds). This can be constructed by appending
'000' to a unix ten digit epoch date.

=head2 facilitatorId (Str)

The userId of the facilitator who created the session. They will
always have moderator access.

=head2 followModerator (Bool)

Whiteboard slides are locked to moderator view.

=head2 fullPermissions (Bool)

Whether participants can perform activities (e.g. use the whiteboard) before
the supervisor arrives.

=head2 id (Int)

The sessionId (meetingId).

=head2 inSessionInvitation (Bool)

Whether moderators can invite other individuals from within the online session

=head2 maxTalkers (Int)

The maximum number of simultaneous talkers.

=head2 moderatorNotes (Str)

General notes for moderators. These are not uploaded to the live session).

=head2 moderatorTelephonyAddress (Str)

Either a PHONE number or SIP address for the moderator for telephone.

=head2 moderatorTelephonyPIN (Str)

PIN for moderator telephony

=head2 name (Str)

Session name.

=head2 participantTelephonyAddress (Str)

Either a PHONE number or SIP address for the participants for telephone.

=head2 participantTelephonyPIN (Str)

PIN for participants telephony.

=head2 participants (Array)

A list of users, groups and invited guest that are attending the session,
along with their access levels (moderators or participants). See
L<Working with Participants>.

=head2 password (Str)

A password for the session (see L<Working with Participants>). 

=head2 privateMeeting (Str)

Whether to hide the session (meeting) from the public schedule.

=head2 profile (Str)

Which user profiles are displayed on mouse-over: C<none>, C<mod>
(moderators only) or C<all>.

=head2 raiseHandOnEnter (Bool)

Raise hands automatically when users join the session.

=head2 recordingObfuscation (Bool)

=head2 recordingResolution (Str)

Resolution of session recording. Options are: C<CG>:course gray,
C<CC>:course color, C<MG>:medium gray, C<MC>:medium color, C<FG>:fine gray,
or C<FC>:fine color

=head2 recordingStatus (Str)

Recording status; C<on>, C<off> or C<remote> (start/stopped by moderator)

=head2 redirectURL (Str)

URL to redirect users to after the online session is over.

=head2 restrictedMeeting (Bool)

Restrict session to only invited participants.

=head2 seats (Int)

Specify the number of seats to reserve on the server.

=head2 serverTelephonyAddress (Str)

Either a PHONE number or SIP address for the server.

=head2 serverTelephonyPIN (Str)

PIN for the server.

=head2 start (HiResDate)

Session start time. This can be constructed by appending '000' to a unix ten
digit epoch date.

=head2 supervised (Bool)

Whether the moderator can see private messages.

=head2 telephonyType (Str)

This can be either C<SIP> or C<PHONE>.

=head2 userNotes (Str)

General notes for users. These are not uploaded to the live session).

=head2 videoWindow (Int)

The maximum number of cameras.


=head1 BUGS AND LIMITATIONS

Maintaining the L<Elive::Entity::Session> abstraction may involve fetches from
several entities. This is mostly transparent, but does have some implications
for the C<list> method:

=over 4

=item * You can only filter on core meeting properties (C<name>, C<start>, C<end>, C<password>, C<deleted>, C<faciltatorId>, C<privateMeeting>, C<allModerators>, C<restrictedMeeting> and C<adapter>).

=item * Access to other properties requires a secondary fetch. This is done
lazily on a per record basis and may be considerably slower. This includes
access to attributes of meeting parameters, server parameter and  participant
list.

=item * recurring meetings are not yet implemented

=item * meeting telephony is not yet tested or supported

=back

=head1 SEE ALSO

Please see L<Elive::View::Session>. This provides an identical interface,
but implements C<insert> and C<update> using ELM 2.x compatible commands.

=cut

1;
