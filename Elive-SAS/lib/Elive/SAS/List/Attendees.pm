package Elive::SAS::List::Attendees;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::SAS::List;
extends 'Elive::SAS::List';

use Elive::SAS::Attendee;

__PACKAGE__->element_class('Elive::SAS::Attendee');

=head1 NAME

Elive::SAS::List::Attendees - Container class for an list of session attendees

=cut

=head1 METHODS

=cut

coerce 'Elive::SAS::List::Attendees' => from 'ArrayRef'
          => via {
	      my @attendees = map {Scalar::Util::blessed($_)? $_ : Elive::SAS::Attendee->new($_)} @$_;
	      Elive::SAS::List::Attendees->new(\@attendees);
};

coerce 'Elive::SAS::List::Attendees' => from 'HashRef'
          => via {
	      my $attendee = Scalar::Util::blessed($_)
		  ? $_
		  : Elive::SAS::Attendee->new($_);

	      Elive::SAS::List::Attendees->new([ $attendee ]);
};

1;
