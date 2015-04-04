package Elive::StandardV3::Recording;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV3';

use Scalar::Util;
use Carp;

use Elive::Util;

=head1 NAME

Elive::StandardV3::Recording - Collaborate Recording instance class

=head1 DESCRIPTION

This class is used to locate and access Collaborate recordings.

=cut

__PACKAGE__->entity_name('RecordingLong');

=head1 PROPERTIES

=head2 recordingId (Long)

The ELM-generated recordingId for the Collaborate session recording.

=cut

has 'recordingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('recordingId');
__PACKAGE__->params(startTime => 'HiResDate',
		    endTime => 'HiResDate',
		    sessionName => 'Str'
    );

=head2 roomStartDate (HiResDate)

The actual start date and time of the session when the recording was made.

=cut

has 'roomStartDate' => (is => 'rw', isa => 'HiResDate',);

=head2 roomEndDate (HiResDate)

The actual end date and time of the session when the recording was made.

=cut

has 'roomEndDate' => (is => 'rw', isa => 'HiResDate',);

=head2 recordingURL (Str)

The URL used to access the recording. This would be the result of calling the buildRecordingUrl command with the recordingId.

=cut

has 'recordingURL' => (is => 'rw', isa => 'Str',);

=head2 secureSignOn (Bool)

This parameter does not apply to ELM.

=cut

has 'secureSignOn' => (is => 'rw', isa => 'Str',);

=head2 creationDate (HiResDate)

The date time in milliseconds UTC that the recording file was created. This is the time when the last attendee leaves and the session stops running, not necessarily the session's scheduled end time.

=cut

has 'creationDate' => (is => 'rw', isa => 'HiResDate',);

=head2 recordingSize (Int)

The size of the recording file in bytes.

=cut

has 'recordingSize' => (is => 'rw', isa => 'Int',);


=head2 roomName (Str)

The scheduled session's name at the time that the session was held.
Case insensitive. 1 - 255 characters.

=cut

has 'roomName' => (is => 'rw', isa => 'Str',);

=head2 sessionId (Int)

The ELM-generated sessionId for the scheduled session. This will be 0 if the scheduled session has been deleted but the corresponding recording has not.

=cut

has 'sessionId' => (is => 'rw', isa => 'Int',);

=head1 METHODS

=cut

=head2 recording_url

    my $recording_url = $recording->recording_url(user_id => 'bob');

Returns a URL for the recording. This provides authenthicated access for
the given user.

=cut

sub recording_url {
    my ($class, %opt) = @_;

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my %params;

    my $recording_id = $opt{recording_id} || $opt{recordingId};

    $recording_id ||= $class->recordingId
	if ref($class);

    croak "unable to determine recording_id"
	unless $recording_id;

    my $params = $class->_freeze({recordingId => $recording_id});

    my $som = $connection->call('BuildRecordingUrl' => %$params);

    my $results = $class->_get_results( $som, $connection );

    my $url = @$results && $results->[0];

    return $url;
}

=head2 list

    my $bobs_recordings = Elive::StandardV3::Recordings->(filter => {userId => 'bob'});

Returns an array of recording objects. You may filter on:

=over 4

=item C<userId> - Matched against C<chairList> and C<nonChairList>

=item C<groupingId> - An Element from the C<groupingList>

=item C<sessionId> - Session identifier

=item C<creatorId> - Session creator

=item C<startTime> - Start of the search date/time range in milliseconds.

=item C<endTime> - End of the search date/time range in milliseconds.

=item C<sessionName> - The session name

=cut

=back

=cut

=head2 delete

    $recording->delete;

Deletes recording content from the server and removes it from any associated sessions.

=cut

1;
