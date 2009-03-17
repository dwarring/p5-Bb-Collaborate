package Elive::Entity::Role;
use warnings; use strict;

use base qw{Elive::Struct};
use Moose;

=head1 NAME

Elive::Entity::Role - Elluminate Role entity class

=head1 DESCRIPTION

This is a structural class for Elive roles.

=cut

__PACKAGE__->entity_name('Role');

has 'roleId' => (is => 'rw', isa => 'Pkey', required => 1);

sub _destringify {
    my $class = shift;
    my $role_id = shift;

    return {
	roleid => sprintf("%d", $role_id || 0),
    }
}

1;
