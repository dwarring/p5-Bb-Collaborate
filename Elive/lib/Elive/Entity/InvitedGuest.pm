package Elive::Entity::InvitedGuest;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Carp;

__PACKAGE__->entity_name('InvitedGuest');
__PACKAGE__->collection_name('InvitedGuests');

has 'invitedGuestId' => (is => 'rw', isa => 'Int');
__PACKAGE__->_alias(id => 'invitedGuestId');
has 'loginName' => (is => 'rw', isa => 'Str');
has 'displayName' => (is => 'rw', isa => 'Str');

coerce 'Elive::Entity::InvitedGuest' => from 'HashRef'
          => via {Elive::Entity::InvitedGuest->construct($_,
						 %Elive::_construct_opts) };

=head1 NAME

Elive::Entity::InvitedGuest - Invited Guest entity class

=head1 DESCRIPTION

This is the entity class for invited guests for a meeting.

=cut

=head1 METHODS

=cut

=head2

Serialize a guest as <displayName> (loginName): e.g. 'Robert (bob)'

=cut

sub stringify {
    my $self = shift;
    my $data = shift || $self;

    return $data
	unless Scalar::Util::refaddr($data);

    return sprintf("%s (%s)", $data->{displayName}, $data->{loginName});
}

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
