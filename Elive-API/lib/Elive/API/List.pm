package Elive::API::List;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Array;
extends 'Elive::Array';

=head1 NAME

Elive::API::List - Base class for an array. Typically chair-persons, participants, courses

=cut

=head1 METHODS

=cut

=head2 add 

    $list->add('111111', '222222');

Add additional elements

=cut

coerce 'Elive::API::List' => from 'ArrayRef'
          => via {
	      my @participants = grep {$_ ne ''} map {split(',')} @$_;
	      Elive::API::List->new(\@participants);
};

coerce 'Elive::API::List' => from 'Str'
          => via {
	      my @participants = grep {$_ ne ''} split(',');

	      Elive::API::List->new(\@participants);
          };

=head2 stringify

Serialises array members by joining their string values with ','. Typically
used to pack SOAP data, E.G. Session chair persons.

=cut

sub stringify {
    my $self = shift;
    my $arr  = shift || $self;
    my $type = shift || $self->element_class;

    return join(',', sort map {Elive::Util::string($_, $type)} @$_)
}


1;
