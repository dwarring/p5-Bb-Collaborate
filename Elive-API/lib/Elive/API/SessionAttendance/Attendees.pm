package Elive::API::SessionAttendance::Attendees;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Scalar::Util;

extends 'Elive::API::List';

use Elive::API::SessionAttendance::Attendee;

__PACKAGE__->element_class('Elive::API::SessionAttendence::Attendee');

=head1 NAME

Elive::API::SessionAttendance::Attendees - Container class for a list of session attendees

=cut

=head1 METHODS

=cut

coerce 'Elive::API::SessionAttendance::Attendees' => from 'ArrayRef'
          => via {
	      my @attendees
		  = (map {Scalar::Util::blessed($_)
			      ? $_
			      : Elive::API::SessionAttendance::Attendee->new($_)
		     } @$_);

	      Elive::API::SessionAttendance::Attendees->new(\@attendees);
};

coerce 'Elive::API::SessionAttendance::Attendees' => from 'HashRef'
          => via {
	      my $attendee = Scalar::Util::blessed($_)
		  ? $_
		  : Elive::API::SessionAttendance::Attendee->new($_);

	      Elive::API::SessionAttendance::Attendees->new([ $attendee ]);
};

1;
