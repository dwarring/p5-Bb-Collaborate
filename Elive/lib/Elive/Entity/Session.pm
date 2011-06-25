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
use Elive::Entity::ParticipantList::Participants;
use Elive::Array;

=head1 NAME

Elive::Entity::Session - ELM 3.x Session insert/update support (TRIAL)

=head1 DESCRIPTION

Elive::Entity::Session implements the C<createSession> and C<updateSession>
commands, introduced with Elluminate 3.0.

They more-or-less replace a series of meeting setup commands including:
C<createMeeting> C<updateMeeting>, C<updateMeetingParameters>,
C<updateServerParameters>, C<setParticipantList> and others.

Some of the newer features and more advanced session setup can only be
acheived via these newer commands.

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

__PACKAGE__->_alias(reservedSeatCount => 'seats', freeze => 1);

__PACKAGE__->_alias(restrictParticipants => 'restrictedMeeting', freeze => 1);

__PACKAGE__->_alias(boundaryTime => 'boundaryMinutes', freeze => 1);

__PACKAGE__->_alias(supervisedMeeting => 'supervised', freeze => 1);

__PACKAGE__->_alias(private => 'privateMeeting', freeze => 1);

__PACKAGE__->_alias(allPermissionsMeeting => 'fullPermissions', freeze => 1);

__PACKAGE__->_alias(sessionServerTeleconferenceType => 'telephonyType', freeze => 1);

__PACKAGE__->_alias(enableTeleconferencing => 'enableTelephony', freeze => 1);

__PACKAGE__->_alias(facilitator => 'facilitatorId', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferenceAddress => 'moderatorTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferencePIN => 'moderatorTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(participantTeleconferenceAddress => 'participantTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(participantTeleconferencePIN => 'participantTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(serverTeleconferenceAddress => 'serverTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(serverTeleconferencePIN => 'serverTelephonyPIN', freeze => 1);

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
    my $participants = Elive::Entity::ParticipantList::Participants->new( $raw );

    ($data->{invitedGuests},
     $data->{invitedModerators},
     $data->{invitedParticipantsList})
	= $participants->tidied(facilitatorId => $data->{facilitatorId});

    return $data
}

=head2 insert

Create a new session using the C<createSession> command

=cut

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

sub insert {
    my $class = shift;
    my %data = %{ shift() };
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection
	or die "not connected";

    my $facilitatorId = $data{facilitatorId} || $connection->login->userId;
    my $participants = Elive::Entity::ParticipantList::Participants->new( $data{participants} );
    $data{participants} = $participants->tidied(facilitatorId => $facilitatorId);

    # todo

    die "recurring meetings not supported"
	if $data{recurrenceCount} || $data{recurrenceDays};

    return $class->SUPER::insert( \%data, command => 'createSession', %opt );
}

=head2 is_changed

Returns a list of properties that have been changed since the Session
was last retrieved or saved.

=cut

sub is_changed {
    my $self = shift;

    my $delegates = $self->_delegates;

    return map {$self->{$_}? $self->$_->is_changed: ()} (sort keys %$delegates)
}

=head2 revert

Reverts any unsaved updates.

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

	my $participants_data = $update_data{participants}
	|| $self->participants;

	my $participants = Elive::Entity::ParticipantList::Participants->new( $participants_data );
	$update_data{participants} = $participants->tidied(facilitatorId => $facilitatorId);

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
    my $self = bless {id => Elive::Util::string($id)}, $class;

    for ($opt{connection}) {
	$self->connection($_) if $_;
    }

    return $self;
}

=head2 list

List all sessions that match a given critera:

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

Deletes an expired or unwanted session from the Elluminate server.

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

1;
