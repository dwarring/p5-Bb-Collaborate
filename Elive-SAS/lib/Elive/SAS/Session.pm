package Elive::SAS::Session;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

use Elive::Util;

use Elive::SAS::List;

=head1 NAME

Elive::SAS::Session - Elluminate Session instance class

=head1 DESCRIPTION

This is the main entity class for sessions.

=cut

__PACKAGE__->entity_name('Session');

has 'sessionId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('sessionId');

has 'accessType' => (is => 'rw', isa => 'Int',
	       documentation => 'creator user id',
    );

has 'allowInSessionInvites' => (is => 'rw', isa => 'Bool',
	       documentation => 'allow in-session invitations',
    );

has 'boundaryTime' => (is => 'rw', isa => 'Int',
	       documentation => 'boundary time minutes: 0, 15, 30...',
    );

has 'chairList' => (is => 'rw', isa => 'Elive::SAS::List', coerce => 1,
	       documentation => 'list of chair-persons (comma separated)',
    );

has 'chairNotes' => (is => 'rw', isa => 'Str',
	       documentation => 'chair notes',
    );

has 'creatorId' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'creator user id',
    );

has 'endTime' => (is => 'rw', isa => 'HiResDate', required => 1,
	      documentation => 'session end time');

has 'groupingList' => (is => 'rw', isa => 'Elive::SAS::List', coerce => 1,
	       documentation => 'list of courses etc (user defined)',
    );

has 'sessionName' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'session name',
    );

has 'hideParticipantNames' => (is => 'rw', isa => 'Bool',
			       documentation => 'Hide Participant Names',
    );

has 'maxCameras' => (is => 'rw', isa => 'Int',
		     documentation => 'maximum simultaneous cameras'
    );

has 'maxTalkers' => (is => 'rw', isa => 'Int',
		     documentation => 'maximum simultaenous talkers'
    );

has 'mustBeSupervised' => (is => 'rw', isa => 'Bool',
			   documentation => 'Session number be supervised',
    );

has 'nonChairList' => (is => 'rw', isa => 'Elive::SAS::List', coerce => 1,
	       documentation => 'list of participants (comma separated)',
    );

has 'nonChairNotes' => (is => 'rw', isa => 'Str',
	       documentation => 'non chair notes',
    );

has 'startTime' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'session start time');

has 'openChair' => (is => 'rw', isa => 'Bool',
		    documentation => 'Let all users act as chairpersons',
    );

has 'permissionsOn' => (is => 'rw', isa => 'Bool',
		    documentation => 'Whether all non chair participcants are granted all permissions',
    );

has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
			   documentation => 'Whether users automaticially raise their hands as they join.',
    );

has 'recordingModeType' => (is => 'rw', isa => 'Int',
			    documentation => '0, 1, 2',
    );

has 'reserveSeats' => (is => 'rw', isa => 'Int',
		       documentation => 'Number of places to reserve on server',
    );

has 'secureSignOn' => (is => 'rw', isa => 'Bool',
		       documentation => 'N/A to ELM',
    );

has 'recordings' => (is => 'rw', isa => 'Bool',
		       documentation => 'Whether session has any recordings',
    );

has 'versionId' => (is => 'rw', isa => 'Int',
		    documentation => 'ELM version Id (E.g. 1001 == 10.0.1)',
    );


=head1 METHODS

=cut

1;
