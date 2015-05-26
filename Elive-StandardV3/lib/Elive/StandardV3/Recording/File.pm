package Elive::StandardV3::Recording::File;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV3';

use Scalar::Util;
use Carp;

use Elive::Util;

=head1 NAME

Elive::StandardV3::Recording::File - Collaborate Recording File response class

=head1 DESCRIPTION

This class is used to return responses to recording conversion requests.

=cut

has 'recordingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('recordingId');
__PACKAGE__->params(format => 'Str',
    );

__PACKAGE__->entity_name('RecordingFile');

has 'recordingStatus' => (is => 'rw', isa => 'Str', required => 1);

=head2 convert_recording

    Elive::StandardV3::RecordingFile->convert_recording( recording_id => $recording_id, format => 'mp4' );

=cut

sub convert_recording {
    my ($class, %opt) = @_;

    my $connection = $opt{connection} || $class->connection
	or croak "Not connected";

    my $recording_id = $opt{recording_id} || $opt{recordingId};
    my $format = $opt{format} || 'mp3';

    $recording_id ||= $class->recordingId
	if ref($class);

    croak "unable to determine recording_id"
	unless $recording_id;

    my $params = $class->_freeze({format => $format});
    return $class->retrieve( $recording_id, connection => $connection, command => 'ConvertRecording', %$params);
}

1;
