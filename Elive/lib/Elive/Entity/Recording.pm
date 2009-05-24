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

has 'creationDate' => (is => 'rw', isa => 'HiResDate', required => 1);
has 'data' => (is => 'rw', isa => 'Str');
has 'facilitator' => (is => 'rw', isa => 'Str');
has 'keywords' => (is => 'rw', isa => 'Str');
has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
has 'open' => (is => 'rw', isa => 'Bool');
has 'roomName' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Int');
has 'version' => (is => 'rw', isa => 'Str');

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

sub _thaw {
    my $class = shift;
    my $data = shift;

    my $data_thawed = $class->SUPER::_thaw($data, @_);

    if (exists $data_thawed->{MeetingRoomId}) {
	$data_thawed->{meetingId} = delete $data_thawed->{MeetingRoomId};
    }

    return $data_thawed;
}

=head2 buildJNLP 

    my $jnlp = $recording_entity->buildJNLP(version => version,
					    userId => $user->userId);

Builds a JNLP for the recording.

JNLP is the 'Java Network Launch Protocol', also commonly known as Java
WebStart. You can render this as a web page with mime type
C<application/x-java-jnlp-file>.

Under Windows, and other desktops, you can save this to a file with extension
C<JNLP>.

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

    for (delete $opt{userId} || $connection->login->userId) {

	$soap_params{'userId'} = Elive::Util::_freeze($_, 'Str');
	#
	# My version of Elluminate 9.1 complains unless I supply
	# (sic) 'userIp' !!?
	#
	$soap_params{'userIp'} = Elive::Util::_freeze($_, 'Str');
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
