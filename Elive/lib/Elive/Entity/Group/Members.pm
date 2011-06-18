package Elive::Entity::Group::Members;
use warnings; use strict;

=head1 NAME

Elive::Entity::Group::Members - Group Members entity class

=cut

use Mouse;
use Mouse::Util::TypeConstraints;
use Scalar::Util;
use Elive::Util;

use Elive::Entity::Group;

extends 'Elive::Array';
__PACKAGE__->separator(',');
__PACKAGE__->element_class('Elive::Entity::Group');

sub _build_array {
    my $class = shift;
    my $spec = shift;

    my $type = Elive::Util::_reftype( $spec );

    my @members;

    if ($type eq 'ARRAY') {
	@members = map {ref($_) && ! Scalar::Util::blessed($_)
			    ? Elive::Entity::Group->new($_)
			    : Elive::Util::string($_)} @$spec;
    }
    else {
	@members = split($class->separator, Elive::Util::string( $spec ));
    }

    return \@members;
}

our $class = 'Elive::Entity::Group::Members';
coerce $class => from 'ArrayRef|Str'
          => via {
	      $class->new( $_ );
          };

1;
