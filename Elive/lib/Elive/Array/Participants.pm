package Elive::Array::Participants;
use warnings; use strict;

use Elive::Array;
use base qw{Elive::Array};

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

1;
