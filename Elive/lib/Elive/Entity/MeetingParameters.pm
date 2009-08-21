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

enum enumRecordingStates => '', qw(on off remote);
has 'recordingStatus' => (is => 'rw', isa => 'enumRecordingStates',
    documentation => 'recording status; on, off or remote (start/stopped by moderator)');
has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
    documentation => 'raise hands automatically when users join');
has 'maxTalkers' => (is => 'rw', isa => 'Int',
    documentation => 'maximum number of simultaneous talkers');
#
# inSessionInvitation - required by ElluminateLive 8.0 - 9.10?
# took a walk in 9.1, but back in 9.5 as inSessionInvitations
#
has 'inSessionInvitation'  => (is => 'rw', isa => 'Bool');
# v9.5
__PACKAGE__->_alias('inSessionInvitations' => 'inSessionInvitation');

has 'followModerator'  => (is => 'rw', isa => 'Bool');
has 'videoWindow'  => (is => 'rw', isa => 'Bool');
has 'recordingObfuscation'  => (is => 'rw', isa => 'Bool');
has 'recordingResolution'  => (is => 'rw', isa => 'Str');
has 'profile'  => (is => 'rw', isa => 'Str');

=head1 NAME

Elive::Entity::MeetingParameters - Meeting parameters entity class

    my $meeting_params
        = Elive::Entity::MeetingParameters->retrieve([$meeting_id]);

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

sub _thaw {
    my $class = shift;
    my $db_data = shift;

    my $data = $class->SUPER::_thaw($db_data, @_);

    for (grep {defined} $data->{recordingStatus}) {

	$_ = lc($_);

	unless (m{^(on|off|remote)$} || $_ eq '') {
	    warn "ignoring unknown recording status: $_";
	    delete  $data->{recordingStatus};
	}
    }

    return $data;
}

=head1 See Also

Elive::Entity::Meeting

=cut

1;
