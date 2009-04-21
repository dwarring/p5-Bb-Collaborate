package Elive::Entity::Preload;
use warnings; use strict;

use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

use SOAP::Lite;  # contains SOAP::Data package

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

has 'type' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'media or blackboard(?)',
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

=head2 import_file

    my $preload1 = Elive::Entity::Preload->import(
             {
		    type => 'whiteboard',
		    mimeType => 'application/octet-stream',
		    name => 'introduction.wbd',
		    ownerId => 357147617360,
                    fileName => $path_on_server
	     },
         );

Create a preload from a file already present on the server.

=cut

sub import_file {
    my $class = shift;
    my $insert_data = shift;
    my %opt = @_;

    $class->SUPER::_insert_class($insert_data,
				 adapter => 'importPreload',
				 %opt);
}

=head2 upload

    my $preload1 = Elive::Entity::Preload->upload(
             {
		    type => 'whiteboard',
		    mimeType => 'application/octet-stream',
		    name => 'introduction.wbd',
		    ownerId => 357147617360,
                    data => $binary_data,
	     },
         );

Create a preload from binary data.

=cut

sub upload {
    my $class = shift;
    my $insert_data = shift;
    my %opt = @_;

    my $binary_data = delete $insert_data->{data};

    my $length = length($binary_data) ||0;

    $opt{param} = {length => $length}
    if $length;

    my $self = $class->SUPER::_insert_class($insert_data, %opt);

    if ($length) {

	my $som = $self->connection->call('streamPreload',
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

    my $data = $preload->download

Create a preload from binary data.

=cut

sub download {
    my $self = shift;
    my %opt = @_;

    my $preload_id = $opt{preload_id};
    $preload_id ||= $self->preloadId
	if ref($self);

    die "unable to get a preload_id"
	unless $preload_id;


    my $som = $self->connection->call('getPreloadStream',
				      preloadId => $self->preloadId,
	    );

    $self->_check_for_errors($som);

    my $results = $self->_get_results($som);

    return  $self->_hex_decode($results->[0])
	if $results->[0];

    return undef;
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

sub _hex_decode {
    my $self = shift;
    my $data = shift;

    return
	unless defined $data;

    $data = '0'.$data
	unless length($data) % 2 == 0;

    my ($non_hex_char) = ($data =~ m{([^0-9a-f])}i);

    die "non hex character in data: ".$non_hex_char
	if (defined $non_hex_char);
    #
    # Works for simple ascii
    $data =~ s{(..)}{chr(hex($1))}ge;

    return $data;
}

sub _hex_encode {
    my $self = shift;
    my $data = shift;

    $data =~ s{(.)}{sprintf("%02x", ord($1))}ges;

    return $data;
}

1;
