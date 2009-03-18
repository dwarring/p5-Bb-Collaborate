package Elive::Entity::Participant;
use warnings; use strict;

use Moose;

use base qw{Elive::Struct};

use Elive::Entity::User;
use Elive::Entity::Role;

__PACKAGE__->entity_name('Participant');

has 'user' => (is => 'rw', isa => 'Elive::Entity::User',
	       documentation => 'User attending the meeting');

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role',
	       documentation => 'Role of the user within this meeting');

=head1 NAME

Elive::Entity::Particpiant - A Single Meeting Participant

=head1 DESCRIPTION

This class cannot be retrieved directly. Rather it is a container
class for participants in an Elive::Entity::ParticpiantList

=head1 SEE ALSO

Elive::Entity::ParticpiantList

=cut

sub _stringify_self {

    my $self = shift;

    #
    # Stringify to the format used for updates: userId=role
    #

    return $self->user.'='.$self->role;
}

sub _destringify {
    my $class = shift;

    #
    # inverse of stringification. resubstantiate the object.
    #

    my $string = shift;

    die "not in format: <user_id>=<rold_id>: $string"
	unless ($string && $string =~ m{^[0-9]+=[0-9]+$});

    my ($user_id, $role_id) = split('=', $string);

    my $user = Elive::Entity::User->retrieve($user_id)
	or die "no such user: $user_id";

    return __PACKAGE__->construct
	({
	    user => $user,
	    role => {
		roleId => $role_id,
	    }
	 });
}

1;
