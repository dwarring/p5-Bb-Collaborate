package Elive::Entity::Group::Members;
use warnings; use strict;

=head1 NAME

Elive::Entity::Group::Members - Group Members entity class

=cut

use Mouse;
use Mouse::Util::TypeConstraints;
use Scalar::Util;

use Elive::Entity::Group;

extends 'Elive::Array';
__PACKAGE__->separator(',');
__PACKAGE__->element_class('Elive::Entity::Group');

coerce 'Elive::Entity::Group::Members' => from 'Str'
          => via {
	      my $a = [ split(__PACKAGE__->separator) ];
	      bless ($a,__PACKAGE__);
          };

coerce 'Elive::Entity::Group::Members' => from 'ArrayRef'
          => via {
	      my @a = map {ref($_) && ! Scalar::Util::blessed($_)
			       ? Elive::Entity::Group->new($_)
			       : Elive::Util::string($_)} @$_;
	      bless (\@a, __PACKAGE__);
          };

1;
