package Elive::Entity::ServerParameters;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

__PACKAGE__->entity_name('ServerParameters');
__PACKAGE__->isa('Meeting');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1,
    documentation => 'associated meeting');
__PACKAGE__->primary_key('meetingId');

has 'seats' => (is => 'rw', isa => 'Int',
    documentation => 'Number of available seats');
has 'boundaryMinutes' => (is => 'rw', isa => 'Int',
    documentation => 'meeting boundary time');
has 'fullPermissions' => (is => 'rw', isa => 'Bool', required => 1,
    documentation => 'whether participants can perform activities (e.g. use whiteboard) before the supervisor arrives');
has 'supervised' => (is => 'rw', isa => 'Bool',
    documentation => 'whether the moderator can see private messages');

has 'enableTelephony' => (is => 'rw', isa => 'Bool');
has 'telephonyType' => (is => 'rw', isa => 'Str');
has 'moderatorTelephonyAddress' => (is => 'rw', isa => 'Str');
has 'moderatorTelephonyPIN' => (is => 'rw', isa => 'Str');
has 'participantTelephonyAddress' => (is => 'rw', isa => 'Str');
has 'participantTelephonyPIN' => (is => 'rw', isa => 'Str');
has 'serverTelephonyAddress' => (is => 'rw', isa => 'Str');
has 'serverTelephonyPIN' => (is => 'rw', isa => 'Str');
has 'serverTelephonyAddress' => (is => 'rw', isa => 'Str');
has 'redirectURL' => (is => 'rw', isa => 'Str');

#
# maintain aliases for version compatibility and freeze/thaw inconsistancies
#

__PACKAGE__->_alias(requiredSeats => 'seats');
__PACKAGE__->_alias(boundaryTime => 'boundaryMinutes'); # v 9.5.0 +
__PACKAGE__->_alias(boundary => 'boundaryMinutes', freeze => 1);
__PACKAGE__->_alias(permissionsOn => 'fullPermissions', freeze => 1);

=head1 NAME

Elive::Entity::ServerParameters - Meeting server parameters entity class

=head1 SYNOPSIS

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $meeting_params
        = Elive::Entity::ServerParameters->retrieve([$meeting->meetingId]);

    $meeting_params->update({
           boundaryMinutes => 15,
           fullPermissions => 0,
           supervised      => 1,
           enableTelephony => 0,
     });
    #
    # Note: the number of seats is read from this class, but updates
    # are performed through the main meeting class
    #
    my $seats = $meeting_params->seats;
    $meeting->update({seats => $seats + 10});

=head1 DESCRIPTION

More meeting options.

=cut

=head1 METHODS

=cut

=head2 insert

The insert method is not applicable. The meeting server parameters table
is automatically created when you create a table.

=cut

sub insert {shift->_not_available}

=head2 delete

The delete method is not applicable. meeting server parameters are deleted
when the meeting itself is deleted.

=cut

sub delete {shift->_not_available}

=head2 list

The list method is not available for meeting parameters. You'll need
to create a meeting, then retrieve on meeting id

=cut

sub list {shift->_not_available}

=head2 update

    my $server_parameters
         = Elive::Entity::ServerParameters->fetch([$meeting_id]);

    $server_parameters->update({
	    boundaryMinutes => 15,
	    fullPermissions => 1,
	    supervised => 1,
        });

Updates the meeting boundary times, permissions and whether the meeting is
supervised.

Note: although maxTalkers (maximum number of simultaneous talkers) is
retrieved via this entity, but must be updated via Elive::Entity::Meeting.

=cut

sub update {
    my $self = shift;
    my $update_data = shift;

    $self->set( %$update_data)
	if (keys %$update_data);

    #
    # SDK seems to require a setting for fullPermissions (aka permissionOns)
    # trap it as an error on our side.
    #
    my @required = qw/boundaryMinutes fullPermissions supervised/;
    my %changed;
    @changed{@required, $self->is_changed} = undef;

    #
    # direct changes to seats are ignored. This needs to be updated
    # via the meeting entity.
    #
    warn "ignoring changed 'seats' value"
	if (exists $changed{seats});

    foreach (@required) {
	die "missing required property: $_"
	    unless defined $self->{$_};
    }

    #
    # This adapter barfs if we don't write values back, whether they've
    # changed or not.
    #
    $self->SUPER::update(undef, @_, changed => [sort keys %changed]);
}

=head1 See Also

Elive::Entity::Meeting
Elive::Entity::MeetingParameters

=cut

1;
