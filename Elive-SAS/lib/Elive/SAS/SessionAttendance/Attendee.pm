package Elive::SAS::SessionAttendance::Attendee;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

=head1 NAME

Elive::SAS::SessionAttendance::Attendee - Elluminate Attendee instance class

=head1 DESCRIPTION

This is the element class of Elive::SAS::SessionAttendance::Attendees

=cut

__PACKAGE__->entity_name('Attendee');

has 'attendeeName' => (is => 'rw', isa => 'Str',
	       documentation => 'attendee user id',
    );

has 'attendeeJoinedAt' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'date/time attendee joined the session');

has 'attendeeLeftAt' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'date/time attendee left the session');

has 'attendeeWasChair' => (is => 'rw', isa => 'Bool',
			   documentation => 'Whether the attendee was a chairperson'
    );

=head1 METHODS

=cut

1;
