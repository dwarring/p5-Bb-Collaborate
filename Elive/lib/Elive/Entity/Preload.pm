package Elive::Entity::Preload;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Util;

use SOAP::Lite;  # contains SOAP::Data package
use MIME::Types;
use File::Basename qw{};

use Carp;

=head1 NAME

Elive::Entity::Preload - Elluminate Preload instance class

=head2 DESCRIPTION

This is the entity class for meeting preloads.

    my $preloads = Elive::Entity::Preload->list(
                        filter =>  'mimeType=application/x-shockwave-flash',
                    );

    my $preload = Elive::Entity::Preload->retrieve([$preload_id]);

    my $type = $preload->type;

There are three possible types of preloads: media, plan and whiteboard.

=cut

__PACKAGE__->entity_name('Preload');
__PACKAGE__->collection_name('Preloads');

has 'preloadId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('preloadId');
__PACKAGE__->params(
    meetingId => 'Str',
    fileName => 'Str',
    );
__PACKAGE__->_alias(key => 'preloadId');

enum enumPreloadTypes => qw(media whiteboard plan);
has 'type' => (is => 'rw', isa => 'enumPreloadTypes', required => 1,
	       documentation => 'preload type. media, whiteboard or plan',
    );

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'preload name, e.g. "intro.wbd"',
    );

has 'mimeType' => (is => 'rw', isa => 'Str', required => 1,
		   documentation => 'The mimetype of the preload (e.g., video/quicktime).');

has 'ownerId' => (is => 'rw', isa => 'Str', required => 1,
		 documentation => 'preload owner (userId)',
    );

has 'size' => (is => 'rw', isa => 'Int', required => 1,
	       documentation => 'The length of the preload in bytes',
    );

has 'data' => (is => 'rw', isa => 'Str',
	       documentation => 'The contents of the preload.');

has 'isProtected' => (is => 'rw', isa => 'Bool');
has 'isDataAvailable' => (is => 'rw', isa => 'Bool');


=head1 METHODS

=cut

=head2 upload

    my $preload = Elive::Entity::Preload->upload(
             {
		    type => 'whiteboard',
		    name => 'introduction.wbd',
		    ownerId => 357147617360,
                    data => $binary_data,
	     },
         );

Upload data from a client and create a preload.  If a C<mimeType> is not
supplied, it will be guessed from the C<fileName> extension, using
MIME::Types.

=cut

sub upload {
    my ($class, $insert_data_ref, %opt) = @_;

    my %insert_data = %{ $insert_data_ref };

    my $binary_data = delete $insert_data{data};
    my $length = delete $insert_data{length} || 0;
    $length ||= length($binary_data)
	if $binary_data;
    #
    # 1. create initial record
    #
    my $self = $class->insert(\%insert_data, %opt);

    if ($length && $binary_data) {
	#
	# 2. Now upload data to it
	#
	my $connection = $self->connection
	    or die "not connected";

	my $som = $connection->call('streamPreload',
				    preloadId => $self->preloadId,
				    length => $length,
				    stream => (SOAP::Data
					       ->type('hexBinary')
					       ->value($binary_data)),
	    );

	$connection->_check_for_errors($som);
    }

    return $self;
}

=head2 download

    my $preload = Elive::Entity::Preload->retrieve([$preload_id]);
    my $binary_data = $preload->download;

Download data for a preload.

=cut

sub download {
    my ($self, %opt) = @_;

    my $preload_id = $opt{preload_id} ||= $self->preloadId;

    die "unable to get a preload_id"
	unless $preload_id;

    my $connection = $self->connection
	or die "not connected";

    my $som = $connection->call('getPreloadStream',
				preloadId => Elive::Util::_freeze($preload_id, 'Int'),
	);

    my $results = $self->_get_results($som, $connection);

    return  Elive::Util::_hex_decode($results->[0])
	if $results->[0];

    return;
}

=head2 import_from_server

    my $preload1 = Elive::Entity::Preload->import_from_server(
             {
		    type => 'whiteboard',
		    name => 'introduction.wbd',
		    ownerId => 357147617360,
                    fileName => $path_on_server
	     },
         );

Create a preload from a file that is already present on the server. If
a C<mimeType> is not supplied, it will be guessed from the C<fileName>
extension using MIME::Types.

=cut

sub import_from_server {
    my ($class, $insert_data, %opt) = @_;

    my $params = $opt{param} || {};

    die "missing required parameter: fileName"
	unless $insert_data->{fileName} || $params->{fileName};

    $opt{command} ||= 'importPreload',;

    return $class->insert($insert_data, %opt);
}

=head2 list_meeting_preloads

my $preloads = Elive::Entity::Preload->list_meeting_preloads($meeting_id);

Implements the listMeetingPreloads method

=cut

sub list_meeting_preloads {
    my ($self, $meeting_id, %opt) = @_;

    die 'usage: $preload_obj->list_meeting_preloads($meeting)'
	unless $meeting_id;

    $opt{command} ||= 'listMeetingPreloads';

    return $self->_fetch({meetingId => $meeting_id}, %opt);
}

sub _freeze {
    my ($class, $db_data, %opt) = @_;

    $db_data = $class->SUPER::_freeze( $db_data, %opt);

    if (my $filename = $db_data->{fileName}) {
	$db_data->{name} ||= File::Basename::basename($filename);
    }

    if ($db_data->{name}) {

	$_ = File::Basename::basename($_)
	    for $db_data->{name};

	$db_data->{mimeType} ||= $class->_guess_mimetype($db_data->{name});
	$db_data->{type}
	||= ($db_data->{name} =~ m{\.wbd$}ix     ? 'whiteboard'
	     : $db_data->{name} =~ m{\.elpx?$}ix ? 'plan'
	     : 'media');
    }

    return $db_data;
}

sub _thaw {
    my ($class, $db_data, %opt) = @_;

    my $db_thawed = $class->SUPER::_thaw($db_data, %opt);

    for (grep {defined} $db_thawed->{type}) {
	#
	# Just to pass type constraints
	#
	$_ = lc($_);

	unless (m{^media|whiteboard|plan$}x) {
	    Carp::carp "ignoring unknown media type: $_";
	    delete $db_thawed->{type};
	}
    }

    return $db_thawed;
}

=head2 update

The update method is not available for preloads.

=cut

sub update {return shift->_not_available}

sub _guess_mimetype {
    my ($class, $filename) = @_;

    our $mime_types ||= MIME::Types->new;
    my $mime_type;
    my $guess;

    unless ($filename =~ m{\.elpx?}x) { # plan
	$mime_type = $mime_types->mimeTypeOf($filename);

	$guess = $mime_type->type
	    if $mime_type;
    }

    $guess ||= 'application/octet-stream';

    return $guess;
}

sub _readback_check {
    my ($class, $update_ref, $rows, @args) = @_;

    #
    # Elluminate 10.0 discards the file extension for whiteboard preloads;
    # bypass check on 'name'.
    #

    my %updates = %{ $update_ref };
    delete $updates{name};

    return $class->SUPER::_readback_check(\%updates, $rows, @args, case_insensitive => 1);
}

=head1 BUGS AND LIMITATIONS

=over 4

=item -- Under Elluminate 9.6.0 and LDAP, you may need to abritrarily add a 'DomN:'
prefix to the owner ID, when creating or updating a meeting.

    $preload->ownerId('Dom1:freddy');

=item -- Elluminate 10.0 strips the file extension from the filename when
whiteboard files are saved or uploaded (C<introduction.wbd> => C<introduction>).
However, if the file lacks an extension to begin with, the request crashes with
the confusing error message: C<"string index out of range: -1">.

=back

=cut

1;
