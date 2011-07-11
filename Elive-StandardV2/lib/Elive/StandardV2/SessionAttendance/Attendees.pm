package Elive::StandardV2::SessionAttendance::Attendees;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Scalar::Util;

extends 'Elive::StandardV2::_List';

use Elive::StandardV2::SessionAttendance::Attendee;

__PACKAGE__->element_class('Elive::StandardV2::SessionAttendence::Attendee');

=head1 NAME

Elive::StandardV2::SessionAttendance::Attendees - Container class for a list of session attendees

=cut

=head1 METHODS

=cut

coerce 'Elive::StandardV2::SessionAttendance::Attendees' => from 'ArrayRef'
          => via {
	      my @attendees
		  = (map {Scalar::Util::blessed($_)
			      ? $_
			      : Elive::StandardV2::SessionAttendance::Attendee->new($_)
		     } @$_);

	      Elive::StandardV2::SessionAttendance::Attendees->new(\@attendees);
};

coerce 'Elive::StandardV2::SessionAttendance::Attendees' => from 'HashRef'
          => via {
	      my $attendee = Scalar::Util::blessed($_)
		  ? $_
		  : Elive::StandardV2::SessionAttendance::Attendee->new($_);

	      Elive::StandardV2::SessionAttendance::Attendees->new([ $attendee ]);
};

1;
