package Elive::Entity::Role;

use Mouse;
use Elive::Struct;
use base qw{Elive::Struct};

=head1 NAME

Elive::Entity::Role - Elluminate Role entity class

=head1 DESCRIPTION

This is a structural class for Elive roles.

=cut

__PACKAGE__->entity_name('Role');

has 'roleId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('roleId');

sub destringify {
    my $class = shift;
    my $role_id = shift;

    return {
	roleid => sprintf("%d", $role_id || 0),
    }
}

1;
