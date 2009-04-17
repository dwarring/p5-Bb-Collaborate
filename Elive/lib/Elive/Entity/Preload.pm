package Elive::Entity::Preload;
use warnings; use strict;

use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

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

=head2 insert

    #
    # Somehow upload the file to the server. ssh, sftp, rync, http ..?
    #
    my $path_on_server = my_server_upload('introduction.wbd');

    my $preload = Elive::Entity::Preload->insert(
             {
		    type => 'whiteboard',
		    mimeType => 'application/octet-stream',
		    name => 'introduction.wbd',
		    ownerId => 357147617360,
	     },
             fileName => $path_on_server,
         );


fileName is the path to a file that has been previously uploaded to the
remote server. This will be imported as the contents of the preload.

=cut

sub _insert_class {
    my $self = shift;
    my $insert_data = shift;
    my %opt = @_;

    my $adapter = 'createPreload';

    if (my $import_file_name = delete $opt{fileName}) {

	$opt{param}->{fileName} = $import_file_name;
	$adapter = 'importPreload';

    }

    $self->SUPER::_insert_class($insert_data, adapter => $adapter, %opt);
}

=head2 list_meeting_preloads

my $preloads = Elive::Entity::Preload->list_meeting_preloads($meeting_id);

Implements the listMeetingPreloads method

=cut

sub list_meeting_preloads {
    my $class = shift;
    my $meeting_id = shift;
    my %opt = @_;

    return $class->fetch({meetingId => $meeting_id},
			 adapter => 'listMeetingPreloads',
			 %opt
	);
}

=head2 check_meeting_preloads

my $preloads = Elive::Entity::Preload->check_meeting_preloads($meeting_id);

Implements the checkMeetingPreloads method

=cut

sub check_meeting_preloads {
    my $class = shift;
    my $meeting_id = shift;

    return $class->fetch({meetingId => $meeting_id},
			 adapter => 'checkMeetingPreloads');
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

    die "that isn't hex data: ".YAML::Dump($data)
	unless (length($data) % 2 == 0
		&& $data =~ m{^[0-9a-f]*$}i);
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
