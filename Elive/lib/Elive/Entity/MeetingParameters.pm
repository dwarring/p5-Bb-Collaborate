package Elive::Entity::MeetingParameters;
use warnings; use strict;

use base qw{ Elive::Entity };
use Moose;

__PACKAGE__->entity_name('MeetingParameters');

has 'meetingId' => (is => 'rw', isa => 'Pkey', required => 1, documentation => 'meeting (foreign-key)');
has 'costCenter' => (is => 'rw', isa => 'Str');
has 'moderatorNotes' => (is => 'rw', isa => 'Str');
has 'userNotes' => (is => 'rw', isa => 'Str');
has 'recordingStatus' => (is => 'rw', isa => 'Str');
has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool');
has 'maxTalkers' => (is => 'rw', isa => 'Int');
has 'inSessionInvitation' => (is => 'rw', isa => 'Bool');

=head1 NAME

Elive::Entity::MeetingParameters - meeting parameters entity class

    my $meeting = Elive::Entity::Meeting->retrieve($meeting_id);
    my $meeting_params
        = Elive::Entity::MeetingParameters->retrieve($meeting_id);

    my $maxTalkers = $meeting_params->maxTalkers;

=head1 DESCRIPTION

This class contains additional meeting information. Note that this entity
is automatically created when you create a meeting.

=head1 See Also

Elive::Entity::Meeting

=cut

1;
