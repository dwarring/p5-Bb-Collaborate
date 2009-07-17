package Elive::Entity::Recording;
use warnings; use strict;
use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

use Elive::Util;

__PACKAGE__->entity_name('Recording');
__PACKAGE__->collection_name('Recordings');

has 'recordingId' => (is => 'rw', isa => 'Str', required => 1);
__PACKAGE__->primary_key('recordingId');

has 'creationDate' => (is => 'rw', isa => 'HiResDate', required => 1,
		       documentation => 'creation date and time of the recording');

has 'data' => (is => 'rw', isa => 'Str',
	       documentation => 'recording byte-stream');

has 'facilitator' => (is => 'rw', isa => 'Str',
		      documentation => 'the creator of the meeting');

has 'keywords' => (is => 'rw', isa => 'Str',
		   documentation => 'keywords for this recording');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1,
		    documentation => 'id of the meeting that created this recording');
__PACKAGE__->_alias(meetingRoomId => 'meetingId');

has 'open' => (is => 'rw', isa => 'Bool',
	       documentation => 'whether to display this recording on the public page');
has 'roomName' => (is => 'rw', isa => 'Str',
		   documentation => 'name of the meeting that created this recording');
has 'size' => (is => 'rw', isa => 'Int',
	       documentation => 'download size (bytes');
has 'version' => (is => 'rw', isa => 'Str',
		  documentation => 'version of Elluminate Live! that created this recording');

=head1 NAME

Elive::Entity::Recording - Elluminate Recording Entity class

=cut

=head1 METHODS

=cut

=head2 download

    my $recording = Elive::Entity::Recording->retrieve([$recording_id]);
    my $binary_data = $recording->download;

Download data for a recording.

=cut

sub download {
    my $self = shift;
    my %opt = @_;

    my $recording_id = $opt{recording_id};
    $recording_id ||= $self->recordingId
	if ref($self);

    die "unable to get a recording_id"
	unless $recording_id;

    my $adapter = Elive->check_adapter('getRecordingStream');

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $som = $connection->call($adapter,
				recordingId => $self->recordingId,
	);

    $self->_check_for_errors($som);

    my $results = $self->_get_results($som);

    return  Elive::Util::_hex_decode($results->[0])
	if $results->[0];

    return undef;
}

=head2 web_url

Utility method to return various website links for the recording. This is
available as both class level and object level methods.

=head3 Examples

    #
    # Class level access.
    #
    my $url = Elive::Entity::Recording->web_url(
                     recording_id => $recording_id,
                     action => 'play',
                     connection => $my_connection);  # optional


    #
    # Object level.
    #
    my $recording = Elive::Entity::Recording->retrieve([$recording_id]);
    my $url = recording->web_url(action => 'join');

=cut

sub web_url {
    my $self = shift;
    my %opt = @_;

    my $recording_id = $opt{recording_id};
    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    if (ref($self)) {
	#
	# dealing with an object
	#
	$recording_id ||= $self->recordingId;
    }
    elsif (ref($recording_id)) {  # an object
	$recording_id = $recording_id->recordingId;
    }

    die "no recording_id given"
	unless $recording_id;

    die "not connected"
	unless $connection;

    my $url = $connection->url;

    my %Actions = (
	'play'   => '%s/play_recording.html?recordingId=%s',
	);

    my $action = $opt{action} || 'play';

    die "unrecognised action: $action"
	unless exists $Actions{$action};

    return sprintf($Actions{$action},
		   $url, $recording_id);
}

=head2 buildJNLP 

    my $jnlp = $recording_entity->buildJNLP(version => version,
					    userId => $user->userId,
					    userIP => $ENV{REMOTE_ADDR});

Builds a JNLP for the recording.

JNLP is the 'Java Network Launch Protocol', also commonly known as Java
WebStart. You can, for example, render this as a web page with mime type
C<application/x-java-jnlp-file>.

The C<userIP> is required by the server and represents the IP address of
the client. It is expected recording is expected launched from a browser
that resolves to the same IP address.

See also L<http://en.wikipedia.org/wiki/JNLP>.

=cut

sub buildJNLP {
    my $self = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $recording_id = $opt{recording_id};

    $recording_id ||= $self->recordingId
	if ref($self);

    die "unable to determine recording_id"
	unless $recording_id;

    my %soap_params = (recordingId => $recording_id);

    for ($opt{userIP}) {
	$soap_params{'userIP'} = Elive::Util::_freeze($_, 'Str')
	    if $_;
    }

    for ($opt{userId} || $connection->login->userId) {

	$soap_params{'userId'} = Elive::Util::_freeze($_, 'Str');
    }

    my $adapter = $self->check_adapter('buildRecordingJNLP');

    my $som = $connection->call($adapter,
				%soap_params,
				);

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Str');
}

1;
