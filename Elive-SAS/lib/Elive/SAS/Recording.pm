package Elive::SAS::Recording;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

use Scalar::Util;
use Carp;

use Elive::Util;

=head1 NAME

Elive::SAS::Recording - Elluminate Recording instance class

=head1 DESCRIPTION

This is the main entity class for recordings.

=cut

__PACKAGE__->entity_name('Recording');

has 'recordingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('recordingId');
__PACKAGE__->params(startTime => 'HiResDate',
		    endTime => 'HiResDate',
		    sessionName => 'Str'
    );

has 'roomStartDate' => (is => 'rw', isa => 'HiResDate',);

has 'roomEndDate' => (is => 'rw', isa => 'HiResDate',);

has 'recordingURL' => (is => 'rw', isa => 'Str',);

has 'secureSignOn' => (is => 'rw', isa => 'Str',);

has 'creationDate' => (is => 'rw', isa => 'HiResDate',);

has 'recordingSize' => (is => 'rw', isa => 'Int',);

has 'roomName' => (is => 'rw', isa => 'Str',);

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

    $params{recordingId} = Elive::Util::_freeze($recording_id, 'Int');

    my $som = $connection->call(
	$class->check_adapter('buildRecordingUrl'),
	%params,
	);

    my $results = $class->_get_results(
	$som,
	);

    my $url = @$results && $results->[0];

    return $url;
}

=head2 list

    my $bobs_recordings = Elive::SAS::Recordings->(filter => {userId => 'bob'});

=cut

sub list {
    my ($self, %opt) = @_;

    $opt{adapter} ||= 'listRecordingLong';

    return $self->SUPER::list(%opt);
}

1;
