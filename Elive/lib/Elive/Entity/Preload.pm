package Elive::Entity::Preload;
use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

=head1 NAME

Elive::Entity::Preload - Elluminate Preload instance class

=head2 DESCRIPTION

This is the accessor class for meeting preloads.

NOTE: All retrieval methods omit the data by default. You can
override this by providing the eager option. 

    my $preloads = Elive::Entity::Preload->list(
                        filter =>  'mimeType=application/x-shockwave-flash',
                        eager => 1);

    my $this_preload = Elive::Entity::Preload->retrieve($preload_id,
                        eager => 1);

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

has 'mimeType' => (is => 'rw', isa => 'Str',
		   documentation => 'The mimetype of the preload (e.g., video/quicktime).');

has 'ownerId' => (is => 'rw', isa => 'Int',
		 documentation => 'preload owner (userId)',
    );

has 'length' => (is => 'rw', isa => 'Int',
	       documentation => 'The length of the preload in bytes',
    );

has 'data' => (is => 'rw', isa => 'Str',
	       documentation => 'The input stream comprising the contents of the file.');

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

my $preloads = Elive::Entity::Preload->meeting_preloads($meeting_id);

Implements the checkMeetingPreloads method

=cut

sub check_meeting_preloads {
    my $class = shift;
    my $meeting_id = shift;

    return $class->fetch({meetingId => $meeting_id},
			 adapter => 'checkMeetingPreloads');
}

#
# put_data. still a work in progress unable to figure out streaming
# SDK doco. Support call with Elluminate to get more information. 
#

sub _put_data {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my $preload_id = $opt{preload_id};
    $preload_id ||= $class->preloadId
	if ref($class);

    die 'usage: $obj->put_data($data) or $class->put_data($data, preload_id => $id)'
	unless (defined $data && $preload_id);

    my $adapter = 'streamPreload';
    $class->require_adapter($adapter);
    my $som = $class->connection->call($adapter,
				       preloadId => $preload_id,
				       length => length($data),
				       stream => $class->_hex_encode($data),
	);

    $class->_check_for_errors($som);
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

sub _freeze {
    my $class = shift;
    my $db_data = shift;

    my $db_frozen = $class->SUPER::_freeze($db_data, @_);

##
## Also a work in progress
##

##    for ($db_frozen->{data}) {
##	if (defined $_ && length($_)) {
##	    # may or may not work - give it a go
##	    $_ = $class->_hex_encode($_);
##	my $adapter = 'setPreloadStream';
##	$class->require_adapter($adapter);
##	my $som = $class->connection->call($adapter,
##					   preloadId => $preload_id);
##	die $som->fault->{ faultstring } if ($som->fault);
##	$class->_hex_decode($som->result);
##	}
##    }

    return $db_frozen;
}    

=head2 insert

Save preload changes. In particular, update the data, if this has changed.

=cut

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
