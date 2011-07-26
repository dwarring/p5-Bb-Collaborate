package Elive::StandardV2::SessionAttendance::Attendee;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV2';

=head1 NAME

Elive::StandardV2::SessionAttendance::Attendee - Elluminate Attendee instance class

=head1 DESCRIPTION

This is the element class of Elive::StandardV2::SessionAttendance::Attendees

=cut

__PACKAGE__->entity_name('Attendee');

=head2 attendeeName (Str)

The display name of the attendee as it appeared in the Elluminate Live! session.

=cut

has 'attendeeName' => (is => 'rw', isa => 'Str',
	       documentation => 'attendee user id',
    );

=head2 attendeeJoinedAt (HiResDate)

The date and time that the attendee joined the session.

Note: This is a epoch date, but to the nearest millsecond.  You can convert it to a standard unix epoch date, by removing the last three digits.

    my $join_date_msec = $attendee->attendeeJoinedAt;
    my $join_date_epoch = substr($date_msec, -3);
    my $join_date_dt = DateTime->from_epoch( epoch => $join_date_epoch );

=cut

has 'attendeeJoinedAt' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'date/time attendee joined the session');

=head2 attendeeJoinedAt (HiResDate)

The date and time that the attendee left the session.

Note: This is also a epoch date, to the nearest millsecond.  See L<attendeeJoinedAt> above:

=cut

has 'attendeeLeftAt' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'date/time attendee left the session');

=head2 attendeeWasChair (Bool)

Flag value that indicates if the attendee joined the session as a chairperson (moderator).

=cut

has 'attendeeWasChair' => (is => 'rw', isa => 'Bool',
			   documentation => 'Whether the attendee was a chairperson'
    );

=head1 METHODS

=cut

1;
