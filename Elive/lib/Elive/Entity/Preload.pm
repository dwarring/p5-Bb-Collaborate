package Elive::Entity::Preload;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Util;

use SOAP::Lite;  # contains SOAP::Data package
use MIME::Types;
use File::Basename qw{};

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
	$insert_data->{type}
	||= ($insert_data->{name} =~ m{\.wbd}i     ? 'whiteboard'
	     : $insert_data->{name} =~ m{\.elpx?}i ? 'plan'
	     : 'media');
    }

    my $self = $class->insert($insert_data, %opt);

    if ($length && $binary_data) {

	my $adapter = $self->check_adapter('streamPreload');

	my $connection = $self->connection
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

    my $adapter = $self->check_adapter('getPreloadStream');

    my $connection = $self->connection
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
a C<mimeType> is not supplied, it will be guessed from the C<fileName>
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
    $insert_data->{type} 
	||= ($filename =~ m{\.wbd}i     ? 'whiteboard'
	     : $filename =~ m{\.elpx?}i ? 'plan'
	     : 'media');
    $insert_data->{name} ||= File::Basename::basename($filename);

    $opt{param}{fileName} = $filename;

    $class->insert($insert_data,
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

    for (grep {defined} $db_thawed->{type}) {
	#
	# Just to pass type constraints
	#
	$_ = lc($_);

	unless (m{^media|whiteboard|plan$}) {
	    warn "ignoring unknown media type: $_";
	    delete $db_thawed->{type};
	}
    }

    return $db_thawed;
}

=head2 update

The update method is not available for preloads.

=cut

sub update {shift->_not_available}

sub _guess_mimetype {
    my $class = shift;
    my $filename = shift;

    our $mime_types ||= MIME::Types->new;
    my $mime_type;
    my $guess;

    unless ($filename =~ m{\.elpx?}) { # plan
	$mime_type = $mime_types->mimeTypeOf($filename);

	$guess = $mime_type->type
	    if $mime_type;
    }

    $guess ||= 'application/octet-stream';

    return $guess;
}

=head1 BUGS AND LIMITATIONS

Under Elluminate 9.6.0 and LDAP, you may need to abritrarily add a 'DomN:'
prefix to the owner ID, when creating or updating a meeting.

    $preload->ownerId('Dom1:freddy');

=cut

1;
