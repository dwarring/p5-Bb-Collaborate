package Elive::SAS::Attendee;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

=head1 NAME

Elive::SAS::Attendee - Elluminate Attendee instance class

=head1 DESCRIPTION

This is the main entity class for attendees.

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
