package Elive::Entity::MeetingParameters;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

__PACKAGE__->entity_name('MeetingParameters');
__PACKAGE__->_isa('Meeting');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1,
    documentation => 'associated meeting');
__PACKAGE__->primary_key('meetingId');

has 'costCenter' => (is => 'rw', isa => 'Str',
    documentation => 'user defined cost center');
__PACKAGE__->_alias('cost_center' => 'costCenter');

has 'moderatorNotes' => (is => 'rw', isa => 'Str',
    documentation => 'meeting instructions for moderator(s)');
__PACKAGE__->_alias('moderator_notes' => 'moderatorNotes');

has 'userNotes' => (is => 'rw', isa => 'Str',
    documentation => 'meeting instructions for all participants');
__PACKAGE__->_alias('user_notes' => 'userNotes');

enum enumRecordingStates => '', qw(on off remote);
has 'recordingStatus' => (is => 'rw', isa => 'enumRecordingStates',
    documentation => 'recording status; on, off or remote (start/stopped by moderator)');
__PACKAGE__->_alias('recording' => 'recordingStatus');

has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool',
    documentation => 'raise hands automatically when users join');
__PACKAGE__->_alias('raise_hands' => 'raiseHandOnEnter');

has 'maxTalkers' => (is => 'rw', isa => 'Int',
    documentation => 'maximum number of simultaneous talkers');
__PACKAGE__->_alias('max_talkers' => 'maxTalkers');
#
# inSessionInvitation - required by ElluminateLive 8.0 - 9.10?
# took a walk in 9.1, but back in 9.5 as inSessionInvitations
#
has 'inSessionInvitation'  => (is => 'rw', isa => 'Bool');
# v9.5
__PACKAGE__->_alias('inSessionInvitations' => 'inSessionInvitation');
__PACKAGE__->_alias('invites' => 'inSessionInvitation');

has 'followModerator'  => (is => 'rw', isa => 'Bool');
has 'videoWindow'  => (is => 'rw', isa => 'Int',
		       documentation => 'Max simultaneous cameras');

has 'recordingObfuscation'  => (is => 'rw', isa => 'Bool');
has 'recordingResolution'  => (is => 'rw', isa => 'Str',
    documentation => 'CG:course gray, CC:course color, MG:medium gray, MC:medium color, FG:fine gray, FC:fine color');
has 'profile'  => (is => 'rw', isa => 'Str',
		   documentation => "Which user profiles are displayed: 'none', 'mod' or 'all'");

=head1 NAME

Elive::Entity::MeetingParameters - Meeting parameters entity class

    use Elive::Entity::MeetingParameters;

    my $meeting_params
        = Elive::Entity::MeetingParameters->retrieve([$meeting_id]);

    $meeting_params->update({
           maxTalkers => 3,
           costCenter => 'acme',
           moderatorNotes => 'be there early!',
           userNotes => "don't be late!",
           recordingStatus => 'on',
           raiseHandsOnEnter => 1,
           inSessionInvitation => 1,
           followModerator => 0,
           videoWindow => 0,
         });

=head1 DESCRIPTION

This class contains a range of options for a previously created meeting.

=cut

=head1 METHODS

=cut

=head2 insert

The insert method is not applicable. The meeting parameters table is
automatically created when you create a table.

=cut

sub insert {return shift->_not_available}

=head2 delete

The delete method is not applicable. meeting parameters are deleted
when the meeting itself is deleted.

=cut

sub delete {return shift->_not_available}

=head2 list

The list method is not available for meeting parameters. You'll need
to create a meeting, then retrieve on meeting id

=cut

sub list {return shift->_not_available}

sub _thaw {
    my ($class, $db_data, @args) = @_;

    my $data = $class->SUPER::_thaw($db_data, @args);

    for (grep {defined} $data->{recordingStatus}) {

	$_ = lc($_);

	unless (m{^(on|off|remote)$}x || $_ eq '') {
	    warn "ignoring unknown recording status: $_\n";
	    delete  $data->{recordingStatus};
	}
    }

    return $data;
}

=head1 See Also

L<Elive::Entity::Meeting>
L<Elive::View::Session>

=cut

1;
