package Elive::View::Session;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity::Session';
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');

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

=head2 buildJNLP check_preload add_preload remove_preload is_participant is_moderator list_preloads list_recordings

These methods are available from L<Elive::Entity::Meeting>.

=head2 adapter allModerators boundaryMinutes costCenter deleted enableTelephony end facilitatorId followModerator fullPermissions id inSessionInvitation maxTalkers moderatorNotes moderatorTelephonyAddress moderatorTelephonyPIN name participantTelephonyAddress participantTelephonyPIN participants password privateMeeting profile raiseHandOnEnter recordingObfuscation recordingResolution recordingStatus redirectURL restrictedMeeting seats serverTelephonyAddress serverTelephonyPIN start supervised telephonyType userNotes videoWindow 

These attributes are available from: L<Elive::Entity::Meeting>, L<Elive::Entity::MeetingParamaters>, L<Elive::Entity::ServerParameters>, L<Elive::Entity::ParticipantList>.

=cut

sub properties {
    my $class = shift;

    my %seen = (meetingId => 1);
    my $delegates = $class->_delegates;

    my @delegate_properties = sort grep {! $seen{$_}++} (
	'id',
	map {$_->properties} sort values %$delegates,
    );

    return @delegate_properties;
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
