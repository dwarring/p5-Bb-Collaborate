package Elive::ParticipantList::Participants;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Array;
extends 'Elive::Array';

use Elive::Entity::ParticipantList::Participant;

__PACKAGE__->element_class('Elive::Entity::ParticipantList::Participant');

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
    my ($class, @args) = @_;

    my @participants = map {Elive::Entity::ParticipantList::Participant->_parse($_)} @args;

    return $class->SUPER::add(@participants);
}

coerce 'Elive::ParticipantList::Participants' => from 'ArrayRef'
          => via {
	      my @participants = map {Elive::Entity::ParticipantList::Participant->_parse($_)} @$_;
	      my $a = [ map {Scalar::Util::blessed($_)? $_ : Elive::Entity::ParticipantList::Participant->new($_)
			} @participants];
	      Elive::ParticipantList::Participants->new($a);
};

coerce 'Elive::ParticipantList::Participants' => from 'Str'
          => via {
	      my @participants = map {Elive::Entity::ParticipantList::Participant->_parse($_)} split(';');

	      my $a = [ map {Elive::Entity::ParticipantList::Participant->new($_)} @participants ];
	      Elive::ParticipantList::Participants->new($a);
          };

1;
