package Elive::Entity::Preload;
use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

=head1 NAME

Elive::Entity::Preload - Elluminate Preload instance class

=head2 DESCRIPTION

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

has 'size' => (is => 'rw', isa => 'Int',
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

    return $class->fetch({meetingId => $meeting_id},
			 adapter => 'listMeetingPreloads');
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

sub _thaw {
    my $class = shift;
    my $db_data = shift;
    #
    # Primary key returned in a field named 'Key'. We require PreloadId
    #
    my $db_thawed = $class->SUPER::_thaw($db_data, @_);

    if (my $preload_id = delete $db_thawed->{Key}) {
	warn "setting preload-id: $preload_id";
	$db_thawed->{preloadId} = $preload_id;
    }

    return $db_thawed;
}

1;
