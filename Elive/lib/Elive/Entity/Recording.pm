package Elive::Entity::Recording;
use warnings; use strict;
use Mouse;

extends 'Elive::Entity';

use Elive::Util;

__PACKAGE__->entity_name('Recording');
__PACKAGE__->collection_name('Recordings');
__PACKAGE__->derivable(url => 'web_url');

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

has 'meetingId' => (is => 'rw', isa => 'Int',
		    documentation => 'id of the meeting that created this recording');
__PACKAGE__->_alias(meetingRoomId => 'meetingId', freeze => 1);

has 'sessionInstanceId' => (is => 'rw', isa => 'Int',
		    documentation => 'id of the session instance that created this recording');

has 'open' => (is => 'rw', isa => 'Bool',
	       documentation => 'whether to display this recording on the public page');
has 'roomName' => (is => 'rw', isa => 'Str',
		   documentation => 'name of the meeting that created this recording');
has 'size' => (is => 'rw', isa => 'Int',
	       documentation => 'recording file size (bytes');
has 'version' => (is => 'rw', isa => 'Str',
		  documentation => 'version of Elluminate Live! that created this recording');

has  'sasId' => (is => 'rw', isa => 'Int');

has 'startDate' => (is => 'rw', isa => 'HiResDate',
		    documentation => 'start date/time of the recording');

has 'endDate' => (is => 'rw', isa => 'HiResDate',
		  documentation => 'end date/time of the recording');

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
    my ($self, %opt) = @_;

    my $recording_id = $opt{recording_id} ||= $self->recordingId;

    die "unable to get a recording_id"
	unless $recording_id;

    my $connection = $self->connection
	or die "not connected";

    my $som = $connection->call('getRecordingStream',
				recordingId => $recording_id,
	);

    my $results = $self->_get_results($som, $connection);

    return  Elive::Util::_hex_decode($results->[0])
	if $results->[0];

    return;
}

=head2 upload

    # get the binary data from somewhere
    open (my $rec_fh, '<', $recording_file)
        or die "unable to open $recording_file: $!";

    my $data = do {local $/ = undef; <$rec_fh>};
    die "no recording data: $recording_file"
        unless ($data && length($data));

    # somehow generate a unique key for the recordingId.
    
    use Time::HiRes();
    my ($seconds, $microseconds) = Time::HiRes::gettimeofday();
    my $recordingId = sprintf("%d%d", $seconds, $microseconds/1000);

    # associate this recording with an existing meeting (optional)
    my $meetingId = '1234567890123';

    my $recording = Elive::Entity:Recording->upload(
             {
                    meetingId => $recordingId.'_'.$meetingId,
                    recordingId => $meetingId,
                    facilitator =>  Elive->login,
                    roomName => 'Meeting of the Smiths',
                    version => Elive->server_details->version,
                    data => $binary_data,
                    size => length($binary_data),
	     },
         );

Upload data from a client and create a recording.

Note: the C<facilitator>, when supplied must match the facilitator for the given C<meetingId>.

=cut

sub upload {
    my ($class, $insert_data, %opt) = @_;

    my $binary_data = delete $insert_data->{data};

    my $self = $class->insert($insert_data, %opt);

    my $size = $self->size;

    if ($size && $binary_data) {

	my $connection = $self->connection
	    or die "not connected";

	my $som = $connection->call('streamRecording',
				    recordingId => $self->recordingId,
				    length => $size,
				    stream => (SOAP::Data
					       ->type('hexBinary')
					       ->value($binary_data)),
	    );

	$connection->_check_for_errors($som);
    }

    return $self;
}

=head2 insert

You'll typically only need to insert recordings yourself if you are importing
or recovering recordings that have not been closed cleanly.

    my $recordingId = "${meetingId}_import";
    my $import_filename = sprintf("%s_recordingData.bin", $recording->recordingId);

    #
    # Somehow import the file to the server. This needs to be uploaded
    # to ${instancesRoot}/${instanceName}/WEB-INF/resources/recordings
    # where $instanceRoot is typically /opt/ElluminateLive/manager/tomcat
    #
    import_recording($import_filename);

    my $recording = Elive::Entity::Recording->insert({
        recordingId => $recordingId,
        roomName => "test recording import",
        creationDate => time().'000',
        meetingId => $meetingId,
        facilitator => $meeting->faciliator,
        version => Elive->server_details->version,
        size => length($number_of_bytes),
   });


The Recording C<insert>, unlike other entities, method requires that you supply
a primary key. This is then used to determine the name of the file to look for
in the recording directory, as in the above example.

The meetingId is optional. Recordings do not have to be associated with a
particular meetings. They will still be searchable and are available for
playback.

=cut

=head2 web_url

Utility method to return various website links for the recording. This is
available as both class level and object level methods.

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
    my ($self, %opt) = @_;

    my $recording_id = $opt{recording_id} || $self->recordingId;
    $recording_id = Elive::Util::_freeze($recording_id, 'Str');

    die "no recording_id given"
	unless $recording_id;

    my $connection = $self->connection || $opt{connection}
	or die "not connected";

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

The C<userIP> is required for elm 9.0+ when C<recordingJNLPIPCheck> has
been set to C<true> in C<configuration.xml> (or set interactively via:
Preferences E<gt>E<gt> Session Access E<gt>E<gt> Lock Recording Playback to Client IP)

It represents a fixed client IP address for launching the recording playback.

See also L<http://wikipedia.org/wiki/JNLP>.

=cut

sub buildJNLP {
    my ($self, %opt) = @_;

    my $connection = $self->connection
	or die "not connected";

    my $recording_id = $opt{recording_id} || $self->recordingId;

    die "unable to determine recording_id"
	unless $recording_id;

    my %soap_params = (recordingId => $recording_id);

    for (map {Elive::Util::_freeze($_, 'Str')} grep {$_} $opt{userIP}) {

	$soap_params{'userIp'} = $_; # elm 9.0 compat
	$soap_params{'userIP'} = $_; # elm 9.1+ compat
    }

    for ($opt{userId} || $connection->login->userId) {

	$soap_params{'userId'} = Elive::Util::_freeze($_, 'Str');
    }

    my $som = $connection->call('buildRecordingJNLP', %soap_params);

    my $results = $self->_get_results($som, $connection);

    return @$results && $results->[0];
}

1;
