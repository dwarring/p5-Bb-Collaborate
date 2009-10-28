package Elive::Array::Participants;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Array;
extends 'Elive::Array';

use Elive::Entity::Participant;

__PACKAGE__->element_class('Elive::Entity::Participant');

=head1 NAME

Elive::Array::Participants - Base class for an array of participants

=cut

=head1 METHODS

=cut

=head2 add 

    $participants->add('111111', '222222');

Add additional participants

=cut

sub add {
    my $class = shift;

    my @participants = map {Elive::Entity::Participant->_parse($_)} @_;

    $class->SUPER::add(@participants);
}

coerce 'Elive::Array::Participants' => from 'ArrayRef'
          => via {
	      my @participants = map {Elive::Entity::Participant->_parse($_)} @$_;
	      my $a = [ map {Scalar::Util::blessed($_)? $_ : Elive::Entity::Participant->new($_)
			} @participants];
	      bless ($a, 'Elive::Array::Participants');
	      $a;
};

coerce 'Elive::Array::Participants' => from 'Str'
          => via {
	      my @participants = map {Elive::Entity::Participant->_parse($_)} split(';');

	      my $a = [ map {Elive::Entity::Participant->new($_)} @participants ];
	      bless ($a,'Elive::Array::Participants');
	      $a;
          };

1;
