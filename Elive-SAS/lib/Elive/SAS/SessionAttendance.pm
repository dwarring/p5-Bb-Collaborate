package Elive::SAS::SessionAttendance;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

use Elive::SAS::List::Attendees;

=head1 NAME

Elive::SAS::SessionAttendance - Elluminate Session Attendance Report

=head1 DESCRIPTION

This is the main entity class for attendees.

=cut

__PACKAGE__->entity_name('SessionAttendance');

##has 'sessionId' => (is => 'rw', isa => 'Int', required => 1);
##__PACKAGE__->primary_key('sessionId');

has 'roomName' => (is => 'rw', isa => 'Str', required => 1,
		   documentation => 'Name of the room'
    );

has 'roomOpened' => (is => 'rw', isa => 'HiResDate', required => 1,
		       documentation => 'date and time that the session was launched');

has 'roomClosed' => (is => 'rw', isa => 'HiResDate', required => 1,
		       documentation => 'date and time that room shut down');

has 'attendees' => (is => 'rw', isa => 'Elive::SAS::List::Attendees',
		    coerce => 1, documentation => 'Session attendees',);

# give soap a helping hand
__PACKAGE__->_alias(attendeeResponseCollection => 'attendees');

=head1 METHODS

=cut

1;
