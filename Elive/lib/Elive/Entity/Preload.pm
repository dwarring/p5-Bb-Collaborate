package Elive::Entity::Preload;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{ Elive::Entity };

use Elive::Util;

use SOAP::Lite;  # contains SOAP::Data package
use MIME::Types;
use File::Basename qw{};

=head1 NAME

Elive::Entity::Preload - Elluminate Preload instance class

=head2 DESCRIPTION

This is the accessor class for meeting preloads.

    my $preloads = Elive::Entity::Preload->list(
                        filter =>  'mimeType=application/x-shockwave-flash',
                    );

    my $this_preload = Elive::Entity::Preload->retrieve([$preload_id]);

=cut

__PACKAGE__->entity_name('Preload');
__PACKAGE__->collection_name('Preloads');

has 'preloadId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('preloadId');

enum enumPreloadTypes => qw(media whiteboard);
has 'type' => (is => 'rw', isa => 'enumPreloadTypes', required => 1,
	       documentation => 'preload type. media or blackboard',
    );

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'preload name',
    );

has 'mimeType' => (is => 'rw', isa => 'Str', required => 1,
		   documentation => 'The mimetype of the preload (e.g., video/quicktime).');

has 'ownerId' => (is => 'rw', isa => 'Int', required => 1,
		 documentation => 'preload owner (userId)',
    );

has 'size' => (is => 'rw', isa => 'Int', required => 1,
	       documentation => 'The length of the preload in bytes',
    );

has 'data' => (is => 'rw', isa => 'Str',
	       documentation => 'The contents of the preload.');

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

Upload data from a client and create a preload.  If a c<mimeType> is not
supplied, it will be guessed from the c<fileName> extension, using
MIME::Types. 

=cut

sub upload {
    my $class = shift;
    my $insert_data = shift;
    my %opt = @_;

    my $binary_data = delete $insert_data->{data};

    my $length = length($binary_data) ||0;

    $opt{param}{length} = $length
        if $length;

    if ($insert_data->{name}) {

	$_ = File::Basename::basename($_)
	    for $insert_data->{name};

	$insert_data->{mimeType} ||= $class->_guess_mimetype($insert_data->{name});
	$insert_data->{type} ||= $insert_data->{name} =~ m{\.wbd}i
	    ? 'whiteboard'
	    : 'media';
    }

    my $self = $class->_insert_class($insert_data, %opt);

    if ($length) {

	my $adapter = Elive->check_adapter('streamPreload');

	my $connection = $opt{connection} || $self->connection
	    or die "not connected";

	my $som = $connection->call($adapter,
				    preloadId => $self->preloadId,
				    length => $length,
				    stream => (SOAP::Data
					       ->type('hexBinary')
					       ->value($binary_data)),
	    );

	$self->_check_for_errors($som);
    }

    return $self;
}

=head2 download

    my $preload = Elive::Entity::Preload->retrieve([$preload_id]);
    my $binary_data = $preload->download;

Download data for a preload.

=cut

sub download {
    my $self = shift;
    my %opt = @_;

    my $preload_id = $opt{preload_id};
    $preload_id ||= $self->preloadId
	if ref($self);

    die "unable to get a preload_id"
	unless $preload_id;

    my $adapter = Elive->check_adapter('getPreloadStream');

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $som = $connection->call($adapter,
				preloadId => $self->preloadId,
	);

    $self->_check_for_errors($som);

    my $results = $self->_get_results($som);

    return  Elive::Util::_hex_decode($results->[0])
	if $results->[0];

    return undef;
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
a c<mimeType> is not supplied, it will be guessed from the c<fileName>
extension using MIME::Types.

=cut

sub import_from_server {
    my $class = shift;
    my $insert_data = shift;
    my %opt = @_;

    my $filename = delete $insert_data->{fileName};

    die "missing fileName parameter"
	unless $filename;

    $insert_data->{mimeType} ||= $class->_guess_mimetype($filename);
    $insert_data->{type} ||= $filename =~ m{\.wbd}i
	    ? 'whiteboard'
	    : 'media';
    $insert_data->{name} ||= File::Basename::basename($filename);

    $opt{param}{fileName} = $filename;

    $class->_insert_class($insert_data,
			  adapter => 'importPreload',
			  %opt);
}

=head2 list_meeting_preloads

my $preloads = Elive::Entity::Preload->list_meeting_preloads($meeting_id);

Implements the listMeetingPreloads method

=cut

sub list_meeting_preloads {
    my $self = shift;
    my $meeting_id = shift;
    my %opt = @_;

    die 'usage: $preload_obj->list_meeting_preloads($meeting)'
	unless $meeting_id;

    $meeting_id = $meeting_id->meetingId
	if (ref($meeting_id));

    return $self->_fetch({meetingId => $meeting_id},
			 adapter => 'listMeetingPreloads',
			 %opt
	);
}

sub _thaw {
    my $class = shift;
    my $db_data = shift;
    my %opt = @_;
    #
    # Primary key returned in a field named 'Key'. We require PreloadId
    #
    my $db_thawed = $class->SUPER::_thaw($db_data, @_);

    if (my $preload_id = delete $db_thawed->{Key}) {
	$db_thawed->{preloadId} = $preload_id;
    }

    return $db_thawed;
}

our $mime_types;

sub _guess_mimetype {
    my $class = shift;
    my $filename = shift;

    $mime_types ||= MIME::Types->new;

    my $mime_type = $mime_types->mimeTypeOf($filename);

    my $guess;
    $guess = $mime_type->type
	if $mime_type;

    $guess ||= 'application/octet-stream';

    return $guess;
}

1;
