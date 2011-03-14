package Elive::View::Session;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Struct';

use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ParticipantList;
use Elive::Util;
use Carp;

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');
__PACKAGE__->_alias(meetingId => 'id');
__PACKAGE__->_alias(sessionId => 'id');

our %delegates = (
    meeting => 'Elive::Entity::Meeting',
    meeting_parameters => 'Elive::Entity::MeetingParameters',
    server_parameters => 'Elive::Entity::ServerParameters',
    participant_list => 'Elive::Entity::ParticipantList',
    );

our %handled = (meetingId => 1);

foreach my $prop (sort keys %delegates) {
    my $class = $delegates{$prop};
    my @delegates = grep {!$handled{$_}++} ($class->properties, $class->derivable);
    push (@delegates, qw{buildJNLP check_preload add_preload remove_preload is_participant us_moderator list_preloads list_recordings})
	if $prop eq 'meeting';

    has $prop
    => (is => 'rw', isa => $class, coerce => 1,
	handles => \@delegates,
	lazy => 1,
	default => sub {$class->retrieve($_[0]->id, copy => 1, connection => $_[0]->connection)},
    );
}
    
=head1 NAME

Elive::View::Session - Session view class

=head1 DESCRIPTION

A session is a consolidated view of meetings, meeting participants, server
parameters and participants.

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

A series of sesions can be created using the C<recurrenceCount> and
C<recurrenceDays> parameters.

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
    my @meeting_props = $class->_owned_by('Elive::Entity::Meeting' => (sort keys %data));

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

   foreach my $delegate (sort keys %delegates) {

	my $delegate_class = $delegates{$delegate};
	my @delegate_props = $self->_owned_by($delegate_class => sort keys %data);
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
    my $self = bless {id => Elive::Util::_string($id)}, $class;

    for ($opt{connection}) {
	$self->connection($_) if $_;
    }

    return $self;
}

=head2 list

List all sessions that match a given critera:

    my $sessions = Elive::View::Session->list( filter => "(name like '*Sample*')" );

Note:

You can only select on core meeting properties (C<name>, C<start>, C<end>, C<password>, C<deleted>, C<faciltatorId>, C<privateMeeting>, C<allModerators>, C<restrictedMeeting> and C<adapter>).  Access to other properties requires a secondary fetch and may be slower.

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
    foreach my $delegate (sort keys %delegates) {
	$self->$delegate->_deleted(1) if $self->{$delegate};
    }

    return 1;
}

sub _owned_by {
    my $class = shift;
    my $delegate_class = shift;
    my @props = @_;

    my $delegate_types = $delegate_class->property_types;
    my $delegate_aliases = $delegate_class->_aliases;
    my %delegate_params = $delegate_class->params;

    return grep {exists $delegate_types->{$_}
		 || exists $delegate_aliases->{$_}
		 || exists $delegate_params{$_};
    } @props
}

sub set {
    my $self = shift;
    my %data = @_;

    foreach my $delegate (sort keys %delegates) {

	my $delegate_class = $delegates{$delegate};
	my @delegate_props = $self->_owned_by($delegate_class => sort keys %data);
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

    my @all_properties = grep {! $seen{$_}++} (
	'id',
	map {$_->properties} sort values %delegates,
    );

    return @all_properties;
}

sub property_types {
    my $class = shift;

    my $id = $class->SUPER::property_types->{id};

    my %property_types = (
	id => $id,
	map { %{$_->property_types} } sort values %delegates,
    );

    delete $property_types{meetingId};

    return \%property_types;
}

sub property_doco {
    my $class = shift;

    return {
	map { %{$_->property_doco} } sort values %delegates,
    };
}

sub derivable {
    my $class = shift;
    return (
	map { $_->derivable } sort values %delegates,
	);
}

=head2 SEE ALSO

L<Elive::Entity::Meeting>
L<Elive::Entity::MeetingParameters>
L<Elive::Entity::ServerParameters>
L<Elive::Entity::ParticipantList>

=cut

1;
