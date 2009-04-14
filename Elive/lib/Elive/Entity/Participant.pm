package Elive::Entity::Participant;
use warnings; use strict;

use Mouse;

use Elive::Struct;
use base qw{Elive::Struct};

use Elive::Entity::User;
use Elive::Entity::Role;

__PACKAGE__->entity_name('Participant');

has 'user' => (is => 'rw', isa => 'Elive::Entity::User|Int',
	       documentation => 'User attending the meeting',
	       coerce => 1,
    );

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role|Int',
	       documentation => 'Role of the user within this meeting',
	       coerce => 1,
    );

=head1 NAME

Elive::Entity::Particpiant - A Single Meeting Participant

=head1 DESCRIPTION

This class cannot be retrieved directly. Rather it is a container
class for participants in an Elive::Entity::ParticpiantList

=head1 SEE ALSO

Elive::Entity::ParticpiantList

=cut

=head1 METHODS

=cut

=head2 stringify

Returns a string of the form userId=role. This value is used for
comparisions, sql display, etc...

=cut

sub stringify {

    my $self = shift;

    #
    # Stringify to the format used for updates: userId=role
    #

    return $self->user.'='.$self->role;
}

1;
