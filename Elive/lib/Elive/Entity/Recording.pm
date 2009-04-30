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

has 'creationDate' => (is => 'rw', isa => 'Int');
has 'data' => (is => 'rw', isa => 'Str');
has 'facilitator' => (is => 'rw', isa => 'Int');
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
    my $som = $self->connection->call($adapter,
				      recordingId => $self->recordingId,
	    );

    $self->_check_for_errors($som);

    my $results = $self->_get_results($som);

    return  Elive::Util::_hex_decode($results->[0])
	if $results->[0];

    return undef;
}

=head2 import_from_server

    my $recording = Elive::Entity::Recording->import_from_server(
             {
                    data => $binary_data,
                    meetingRoomId => $_->meeting_id
                    facilitator => $facilitator_id,
                    fileName => $path_on_server
	     },
         );

Create a recording from a file that is already present on the server.

=cut

sub import_from_server {
    my $class = shift;
    my $insert_data = shift;
    my %opt = @_;

    my $filename = delete $insert_data->{fileName};

    die "missing fileName parameter"
	unless $filename;

    $opt{param}{fileName} = $filename;

    $class->SUPER::_insert_class($insert_data,
				 adapter => 'importRecording',
				 %opt);
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

1;
