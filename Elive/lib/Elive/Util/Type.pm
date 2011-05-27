package Elive::Util::Type;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

=head1 NAME

Elive::Util::Type - Type introspection class

=cut

has 'raw_type' => (is => 'rw', isa => 'Any', required => 1);
has 'type' => (is => 'rw', isa => 'Str', required => 1);
has 'array_type' => (is => 'rw', isa => 'Str');
has 'elemental_type' => (is => 'rw', isa => 'Str', required => 1);

#
# hoping to get rid of build args and base this entirely on
# Mouse::Meta::TypeConstraints
# 

sub BUILDARGS {
    my ($class, $raw) = @_;

    my $raw_type = $raw;

    die "missing 'type' argument" unless $raw_type;

    my %cooked;
    $cooked{type} = $raw_type;

    (my $type) = split(/[ \| \] ]/x, $raw_type);

    my $array_type;
    my $elemental_type = $type;

    if ($type =~ m{^Elive::}) {

	if ($type->can('element_class')) {
	    $elemental_type = $type->element_class || 'Str';
	    $array_type = $type;
	}
    }

    $cooked{raw_type} = $raw_type;
    $cooked{type} = $type;
    $cooked{array_type} = $array_type if defined $array_type;
    $cooked{elemental_type} = $elemental_type;

    return \%cooked;
}

=head1 METHODS

=head2 is_struct

    Return true, if the type is an ancestor of Elive::Struct

=cut

sub is_struct {
    my $self = shift;

    my $elemental_type = $self->elemental_type;
    return ($elemental_type  =~ m{^Elive::}
	    && $elemental_type->isa('Elive::Struct'));
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
