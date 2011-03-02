package Elive::Entity::Role;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Struct';

=head1 NAME

Elive::Entity::Role - Elluminate Role entity class

=head1 DESCRIPTION

This is a structural class for Elive roles. It is a component of the
L<Elive::Entity::User> and L<Elive::Entity::Participants::Participant>
entities.

=cut

__PACKAGE__->entity_name('Role');

has 'roleId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('roleId');

coerce 'Elive::Entity::Role' => from 'HashRef'
          => via {Elive::Entity::Role->new($_) };

coerce 'Elive::Entity::Role' => from 'Int'
          => via {Elive::Entity::Role->new({roleId => $_}) };

1;
