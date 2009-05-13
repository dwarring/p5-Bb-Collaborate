package Elive::Entity::MeetingParameters;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{ Elive::Entity };

__PACKAGE__->entity_name('MeetingParameters');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1,
    documentation => 'associated meeting');
__PACKAGE__->primary_key('meetingId');

has 'costCenter' => (is => 'rw', isa => 'Str',
    documentation => 'user defined cost center');
has 'moderatorNotes' => (is => 'rw', isa => 'Str',
    documentation => 'meeting instructions for moderator(s)');
has 'userNotes' => (is => 'rw', isa => 'Str',
    documentation => 'meeting instructions for all participants');

enum enumRecordingStates => '', qw(ON OFF REMOTE);
has 'recordingStatus' => (is => 'rw', isa => 'enumRecordingStates',
    documentation => 'recording status; ON, OFF or REMOTE (start/stopped by moderator)');
has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
    documentation => 'raise hands automatically when users join');
has 'maxTalkers' => (is => 'rw', isa => 'Int',
    documentation => 'maximum number of simultaneous talkers');

=head1 NAME

Elive::Entity::MeetingParameters - Meeting parameters entity class

    my $meeting = Elive::Entity::Meeting->retrieve(\%meeting_data);
    my $meeting_params
        = Elive::Entity::MeetingParameters->retrieve([$meeting->meetingId]);

    $meeting_params->maxTalkers(5);
    $meeting_params->update;

=head1 DESCRIPTION

This class contains additional meeting information.

=cut

=head1 METHODS

=cut

=head2 create

The create method is not applicable. The meeting parameters table is
automatically created when you create a table.

=cut

sub create {shift->_not_available}

=head2 delete

The delete method is not applicable. meeting parameters are deleted
when the meeting itself is deleted.

=cut

sub delete {shift->_not_available}

=head2 list

The list method is not available for meeting parameters. You'll need
to create a meeting, then retrieve on meeting id

=cut

sub list {shift->_not_available}

=head1 See Also

Elive::Entity::Meeting

=cut

1;
