package Elive::StandardV3::Session::Attendees;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Scalar::Util;

extends 'Elive::StandardV3::_List';

use Elive::StandardV3::Session::Attendee;

__PACKAGE__->element_class('Elive::StandardV3::SessionAttendence::Attendee');

=head1 NAME

Elive::StandardV3::Session::Attendees - Container class for a list of session attendees

=cut

=head1 METHODS

=cut

coerce 'Elive::StandardV3::Session::Attendees' => from 'ArrayRef'
          => via {
	      my @attendees
		  = (map {Scalar::Util::blessed($_)
			      ? $_
			      : Elive::StandardV3::Session::Attendee->new($_)
		     } @$_);

	      Elive::StandardV3::Session::Attendees->new(\@attendees);
};

coerce 'Elive::StandardV3::Session::Attendees' => from 'HashRef'
          => via {
	      my $attendee = Scalar::Util::blessed($_)
		  ? $_
		  : Elive::StandardV3::Session::Attendee->new($_);

	      Elive::StandardV3::Session::Attendees->new([ $attendee ]);
};

1;
