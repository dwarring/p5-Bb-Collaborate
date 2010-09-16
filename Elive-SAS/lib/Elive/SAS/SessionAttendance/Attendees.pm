package Elive::SAS::SessionAttendance::Attendees;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Scalar::Util;

extends 'Elive::SAS::List';

use Elive::SAS::SessionAttendance::Attendee;

__PACKAGE__->element_class('Elive::SAS::SessionAttendence::Attendee');

=head1 NAME

Elive::SAS::SessionAttendance::Attendees - Container class for a list of session attendees

=cut

=head1 METHODS

=cut

coerce 'Elive::SAS::SessionAttendance::Attendees' => from 'ArrayRef'
          => via {
	      my @attendees = map {Scalar::Util::blessed($_)? $_ : Elive::SASi::SessionAttendance::Attendee->new($_)} @$_;
	      Elive::SAS::SessionAttendance::Attendees->new(\@attendees);
};

coerce 'Elive::SAS::SessionAttendance::Attendees' => from 'HashRef'
          => via {
	      my $attendee = Scalar::Util::blessed($_)
		  ? $_
		  : Elive::SAS::SessionAttendance::Attendee->new($_);

	      Elive::SAS::SessionAttendance::Attendees->new([ $attendee ]);
};

1;
