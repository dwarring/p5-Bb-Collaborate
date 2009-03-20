package Elive::Entity::MeetingParameters;

use Moose;
use Elive::Entity;
use base qw{ Elive::Entity };

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

This class contains additional meeting information.

=back

=head2 create

The create method is not applicable. The meeting parameters table is
automatically created when you create a table.

=back

=cut

sub create {die "not applicable to meeting parameters"};

=head2 list

The list method is not available for meeting parameters. You'll need
to retrieve on a meeting id.

=back

=cut

sub list {die "not available for meeting parameters"};

=head1 See Also

Elive::Entity::Meeting

=cut

1;
