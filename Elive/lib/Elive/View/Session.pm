package Elive::View::Session;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::DAO';

use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ParticipantList;
use Elive::Util;
use Carp;

__PACKAGE__->mk_classdata('_delegates');

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');
__PACKAGE__->_alias(meetingId => 'id');
__PACKAGE__->_alias(sessionId => 'id');

__PACKAGE__->_delegates({
    meeting => 'Elive::Entity::Meeting',
    meeting_parameters => 'Elive::Entity::MeetingParameters',
    server_parameters => 'Elive::Entity::ServerParameters',
    participant_list => 'Elive::Entity::ParticipantList',
    });

sub _delegate {
    my $pkg = shift;

    our %handled = (meetingId => 1);
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
		default => sub {$class->retrieve($_[0]->id, copy => 1, connection => $_[0]->connection)},
	    );
    }
}

__PACKAGE__->_delegate;
    
=head1 NAME

Elive::View::Session - Session view class

=head1 DESCRIPTION

A session is a consolidated view of meetings, meeting parameters, server parameters and participants.

=cut

=head1 METHODS

=cut

=head2 insert

Creates a new session on an Elluminate server.

    use Elive::View::Session;

    my $session_start = time();
    my $session_end = $session_start + 900;

    $session_start .= '000';
    $session_end .= '000';

    my %session_data = (
	name => 'An example session',
	facilitatorId => Elive->login->userId,
	password => 'example', # what else?
	start =>  $session_start,
	end => $session_end,
	privateMeeting => 1,
	costCenter => 'example',
	recordingStatus => 'remote',
	raiseHandOnEnter => 1,
	maxTalkers => 2,
	inSessionInvitation => 1,
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
	seats => 2,
        participants => [qw(alice bob)],
    );

    my $session = Elive::View::Session->insert( \%session_data );

A series of sessions can be created using the C<recurrenceCount> and C<recurrenceDays> parameters.

    #
    # create three weekly sessions
    #
    my @sessions = Elive::View::Session->insert({
                            ...,
                            recurrenceCount => 3,
                            recurrenceDays  => 7,
                        });
=cut

sub insert {
    my $class = shift;
    my %data = %{ shift() };
    my %opts = @_;

    #
    # start by inserting the meeting
    #
    my @meeting_props = $class->_data_owned_by('Elive::Entity::Meeting' => (sort keys %data));

    my %meeting_data = map {
	$_ => delete $data{$_}
    } @meeting_props;

    #
    # recurrenceCount, and recurrenceDays may result in multiple meetings
    #
    my @meetings = Elive::Entity::Meeting->insert(\%meeting_data, %opts);

    my @objs = map {
	my $meeting = $_;

	my $self = bless {id => $meeting->meetingId,
			  meeting => $meeting}, $class;
	$self->connection( $meeting->connection );
	#
	# from here on in, it's just a matter of updating attributes owned by
	# the other entities. We need to do this for each meeting instance
	#
	$self->update(\%data, %opts)
	    if keys %data;

	$self;

    } @meetings;

    return wantarray? @objs : $objs[0];
}

=head2 update

Updates a previously created session.

    $session->seats(5);
    $session->update;

...or equivalently...

    $session->update({seats => 5});

=cut

sub update {
    my $self = shift;
    my %data = %{ shift() };
    my %opts = @_;

    my $preloads = delete $data{add_preload};
    my $delegates = $self->_delegates;

   foreach my $delegate (sort keys %$delegates) {

	my $delegate_class = $delegates->{$delegate};
	my @delegate_props = $self->_data_owned_by($delegate_class => sort keys %data);
	next unless @delegate_props
	    || ($self->{$delegate} && $self->{$delegate}->is_changed);

	my %delegate_data = map {$_ => delete $data{$_}} @delegate_props;

	$self->$delegate->update( \%delegate_data, %opts );
    }

    if ($preloads) {
	$preloads = [$preloads]
	    unless Elive::Util::_reftype($preloads) eq 'ARRAY';

	foreach my $preload (@$preloads) {
	    $self->meeting->add_preload( $preload );
	}
    }

    return $self;
}

=head2 retrieve

Retrieves a session for the given session id.

    Elive::View::Session->retrieve( $session_id );

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

    my $sessions = Elive::View::Session->list( filter => "(name like '*Sample*')" );

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

    my $session = Elive::View::Session->retrieve( $session_id );
    $session->delete;

=cut

sub delete {
    my $self = shift;
    my %opt = @_;

    $self->meeting->delete;
    my $delegates = $self->_delegates;

    foreach my $delegate (sort keys %$delegates) {
	$self->$delegate->_deleted(1) if $self->{$delegate};
    }

    return 1;
}

=head2 buildJNLP check_preload add_preload remove_preload is_participant is_moderator list_preloads list_recordings

These methods are available from L<Elive::Entity::Meeting>.

=head2 adapter allModerators boundaryMinutes costCenter deleted enableTelephony end facilitatorId followModerator fullPermissions id inSessionInvitation maxTalkers moderatorNotes moderatorTelephonyAddress moderatorTelephonyPIN name participantTelephonyAddress participantTelephonyPIN participants password privateMeeting profile raiseHandOnEnter recordingObfuscation recordingResolution recordingStatus redirectURL restrictedMeeting seats serverTelephonyAddress serverTelephonyPIN start supervised telephonyType userNotes videoWindow 

These attributes are available from: L<Elive::Entity::Meeting>, L<Elive::Entity::MeetingParamaters>, L<Elive::Entity::ServerParameters>, L<Elive::Entity::ParticipantList>.

=cut

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

	$delegate_class->set( %delegate_data );
    }

    carp 'unknown session attributes '.join(' ', sort keys %data).'. expected: '.join(' ', sort $self->properties)
	if keys %data;

    return $self;
}

sub properties {
    my $class = shift;

    my %seen = (meetingId => 1);
    my $delegates = $class->_delegates;

    my @all_properties = sort grep {! $seen{$_}++} (
	'id',
	map {$_->properties} sort values %$delegates,
    );

    return @all_properties;
}

sub property_types {
    my $class = shift;

    my $id = $class->SUPER::property_types->{id};
    my $delegates = $class->_delegates;

    my %property_types = (
	id => $id,
	map { %{$_->property_types} } sort values %$delegates,
    );

    delete $property_types{meetingId};

    return \%property_types;
}

sub property_doco {
    my $class = shift;

    my $delegates = $class->_delegates;

    return {
	map { %{$_->property_doco} } sort values %$delegates,
    };
}

sub derivable {
    my $class = shift;

    my $delegates = $class->_delegates;

    return (
	map { $_->derivable } sort values %$delegates,
	);
}

=head1 BUGS AND LIMITATIONS

Maintaining the L<Elive::View::Session> abstraction may involve fetches from
several entities. This is mostly transparent, but does have some implications
for the C<list> method:

=over 4

=item * You can only filter on core meeting properties (C<name>, C<start>, C<end>, C<password>, C<deleted>, C<faciltatorId>, C<privateMeeting>, C<allModerators>, C<restrictedMeeting> and C<adapter>).

=item * Access to other properties requires a secondary fetch. This is done
lazily on a per record basis and may be considerably slower. This includes
access to attributes of meeting parameters, server parameter and  participant
list.

=back

=cut

1;
