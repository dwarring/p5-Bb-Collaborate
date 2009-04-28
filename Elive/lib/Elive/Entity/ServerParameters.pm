package Elive::Entity::ServerParameters;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{ Elive::Entity };

__PACKAGE__->entity_name('ServerParameters');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1,
    documentation => 'associated meeting');
__PACKAGE__->primary_key('meetingId');

has 'seats' => (is => 'rw', isa => 'Int',
    documentation => 'Number of available seats');
has 'boundaryMinutes' => (is => 'rw', isa => 'Int', required => 1,
    documentation => 'meeting boundary time(mins)');
has 'fullPermissions' => (is => 'rw', isa => 'Bool', required => 1,
    documentation => 'whether participants can perform activities (e.g. use whiteboard) before the supervisor arrives');
has 'supervised' => (is => 'rw', isa => 'Bool',
    documentation => 'whether the moderator can see private messages');

=head1 NAME

Elive::Entity::ServerParameters - meeting server parameters entity class

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $meeting_params
        = Elive::Entity::ServerParameters->retrieve([$meeting->meetingId]);

    $meeting_params->boundary(15); # 15 min boundary on start time
    $meeting_params->update;
    
    #
    # Note: the number of seats is read from this class, but updates
    # are performed through the main meeting class
    #
    my $seats = $meeting_params->seats;
    $meeting->update({seats => $seats + 10});

=head1 DESCRIPTION

More meeting parameters.

=cut

=head1 METHODS

=cut

=head2 create

The create method is not applicable. The meeting server parameters table
is automatically created when you create a table.

=cut

sub create {shift->_not_available}

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

=head1 See Also

Elive::Entity::Meeting
Elive::Entity::MeetingParameters

=cut

sub _freeze {
    my $class = shift;
    my $data = shift;

    warn YAML::Dump({server_parameter_data => $data})
	if $class->debug;


    my $frozen = $class->SUPER::_freeze($data, @_);
    #
    # update parameters don't quite match readback
    warn YAML::Dump({frozen => $frozen})
	if $class->debug;

    $frozen->{boundary} =  delete $frozen->{boundaryMinutes};
    $frozen->{permissionsOn} =  delete $frozen->{fullPermissions};

    return $frozen;

}

sub update {
    my $self = shift;
    my $data = shift;
    #
    # This adaptor barfs if we don't write values back, whether they've
    # changed or not! override normal optimisations and write everything
    # back!
    #
    $self->SUPER::update($data, @_,
			 changed => [qw/seats boundaryMinutes fullPermissions supervised/]);
}

1;
