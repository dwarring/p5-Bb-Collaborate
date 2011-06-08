package Elive::Util::Type;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

=head1 NAME

Elive::Util::Type - Type introspection class

=cut

has 'type' => (is => 'rw', isa => 'Str', required => 1);
has 'array_type' => (is => 'rw', isa => 'Str');
has 'elemental_type' => (is => 'rw', isa => 'Str', required => 1);

#
# hoping to get rid of build args and base this entirely on
# Mouse::Meta::TypeConstraints
# 

sub BUILDARGS {
    my ($class, $type) = @_;

    my %info;

    #
    # Bit of a hack, only works on Elive specific types and type unions.
    #

    my $array_type;
    my $elemental_type = $type;

    if ($type =~ m{^Elive::}) {

	if ($type->can('element_class')) {
	    $elemental_type = $type->element_class || 'Str';
	    $array_type = $type;
	}
    }

    $info{type} = $type;
    $info{array_type} = $array_type if defined $array_type;
    $info{elemental_type} = $elemental_type;

    return \%info;
}

=head1 METHODS

=head2 is_struct

    Return true, if the type is an ancestor of Elive::DAO

=cut

sub is_struct {
    my $self = shift;

    my $elemental_type = $self->elemental_type;
    return ($elemental_type  =~ m{^Elive::}
	    && $elemental_type->isa('Elive::DAO'));
}

=head2 is_ref

    Return true if the elemental_type is a reference; including objects.

=cut

sub is_ref {
    my $self = shift;

    return $self->is_array || $self->is_struct || $self->elemental_type =~ m{^Ref}x;
}

=head2 is_array

    Return true if elements are contained in an array

=cut

sub is_array {
    my $self = shift;

    return $self->array_type;
}

1;
