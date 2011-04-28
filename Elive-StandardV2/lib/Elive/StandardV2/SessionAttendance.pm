package Elive::StandardV2::SessionAttendance;
use warnings; use strict;

use Mouse;
use Carp;

extends 'Elive::StandardV2';

use Elive::StandardV2::SessionAttendance::Attendees;

=head1 NAME

Elive::StandardV2::SessionAttendance - Elluminate Session Attendance Report

=head1 DESCRIPTION

This is the main entity class for attendees.

=cut

__PACKAGE__->entity_name('SessionAttendance');
__PACKAGE__->params(sessionId => 'Int',
		    startTime => 'HiResDate',
		    endTime => 'HiResDate',
    );

has 'roomName' => (is => 'rw', isa => 'Str', required => 1,
		   documentation => 'Name of the room'
    );

has 'roomOpened' => (is => 'rw', isa => 'HiResDate', required => 1,
		       documentation => 'date and time that the session was launched');

has 'roomClosed' => (is => 'rw', isa => 'HiResDate', required => 1,
		       documentation => 'date and time that room shut down');

has 'attendees' => (is => 'rw', isa => 'Elive::StandardV2::SessionAttendance::Attendees',
		    coerce => 1, documentation => 'Session attendees',);

# give soap a helping hand
__PACKAGE__->_alias(attendeeResponseCollection => 'attendees');

=head1 METHODS

=cut

=head2 list

    my $session_id = '123456789012';
    my $yesterday = DateTime->today->subtract(days => 1);

    my $attendance = Elive::StandardV2::SessionAttendance->list(
                                    sessionId => $session_id,
                                    startTime => $yesterday->epoch.'000');

Gets a session attendance report. It returns a reference to an array of Elive::StandardV2::SessionAttendance objects.

=cut

1;
