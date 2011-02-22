package Elive::Entity::InvitedGuest;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Carp;

__PACKAGE__->entity_name('InvitedGuest');
__PACKAGE__->collection_name('InvitedGuests');

has 'invitedGuestId' => (is => 'rw', isa => 'Int', required => 1);
has 'loginName' => (is => 'rw', isa => 'Str', required => 1);
has 'displayName' => (is => 'rw', isa => 'Str');

=head1 NAME

Elive::Entity::InvitedGuest - Invited Guest entity class

=head1 DESCRIPTION

This is the entity class for invited guests for a meeting.

=cut

=head1 METHODS

=cut

sub _retrieve_all {
    my ($class, $vals, %opt) = @_;

    #
    # No getXxxx command use listXxxx
    #
    return $class->SUPER::_retrieve_all($vals,
				       command => 'listInvitedGuests',
				       %opt);
}

=head1 SEE ALSO

=over 4

=item Elive::Entity::Session
=item Elive::Entity::Meeting

=back

=cut

1;
