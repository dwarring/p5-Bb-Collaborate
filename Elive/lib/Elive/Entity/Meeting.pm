package Elive::Entity::Meeting;
use warnings; use strict;

use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

=head1 NAME

Elive::Entity::Meeting - Elluminate Meeting instance class

=cut


__PACKAGE__->entity_name('Meeting');
__PACKAGE__->collection_name('Meetings');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

has 'password' => (is => 'rw', isa => 'Str',
		   documentation => 'optional meeting password');

has 'deleted' => (is => 'rw', isa => 'Bool');

has 'facilitatorId' => (is => 'rw', isa => 'Int',
			documentation => 'userId of facilator');

has 'start' => (is => 'rw', isa => 'Int', required => 1,
		documentation => 'meeting start time (hires)');

has 'privateMeeting' => (is => 'rw', isa => 'Bool');

has 'end' => (is => 'rw', isa => 'Int', required => 1,
	      documentation => 'meeting end time (hires)');

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'meeting name',
    );

=head1 METHODS

=cut

=head2 list_user_meetings_by_date

=head3 synopsis

   $meetings_array_ref
           =  Elive::Entity::Meeting->list_user_meetings_by_date(
                         [$user_obj_or_id,
                          $hires_start_date,
                          $hires_end_date]
                      );

=head3 example

   my $now = DateTime->now;
   my $next_week = $now->clone->add(days => 7);

   my $meetings = Elive::Entity::Meeting->list_user_meetings_by_date(
    [$user_id, $now->epoch * 1000, $next_week->epoch * 1000]
  )

=head3 description

Lists all meetings for which this user is a participant.

Implements the ListUserMeetingsByDateCommand SDK method.

=cut

sub list_user_meetings_by_date {
    my $class = shift;
    my $params = shift;
    my %opt = @_;

    die 'usage: $class->user_meetings_by_date([$user, $start_date, $end_date])'
	unless (Elive::Util::_reftype($params) eq 'ARRAY'
		&& $params->[0] && @$params <= 3);

    my %fetch;
    @fetch{qw{userId startDate endDate}} = @_; 

    return $class->_fetch(\%fetch,
			  adapter => 'listUserMeetingsByDateCommand',
			  %opt,
	);
}

=head2 meeting_url

Utility method to return various website url's for the meeting. This is
available as both class level and object level methods.

=head3 Examples

    #
    # Class level access. This may save an unessesary fetch.
    #
    my $url = Elive::Entity::Meeting->meeting_url(
                     meeting_id => $meeting_id,
                     action => 'join',    # join|edit|...
                     connection => $my_connection);  # optional


    #
    # Object level.
    #
    my $meeting = Elive::Entity::Meeting->retrieve($meeting_id);
    my $url = meeting->meeting_url(action => 'join');

=cut

sub meeting_url {
    my $self = shift;
    my %opt = @_;

    my $meeting_id = $opt{meeting_id};
    my $connection = ($opt{connection}
		      || $self->connection);

    if (ref($self)) {
	#
	# dealing with an object
	#
	$meeting_id ||= $self->meetingId;
    }

    die "no meeting_id given"
	unless $meeting_id;

    die "not connected"
	unless $connection;

    my $url = $connection->url;

    $url =~ s{ / (\Q'webservice.event\E)? $ } {}x;

    my %Actions = (
	'join'   => '%s/join_meeting.html?meetingId=%ld',
	'edit'   => '%s/modify_meeting.event?meetingId=%ld',
	'delete' => '%s/delete_meeting?meetingId=%ld',
	);

    my $action = $opt{action} || 'join';

    die "unrecognised action: $action"
	unless exists $Actions{$action};

    return sprintf($Actions{$action},
		   $url, $meeting_id);
}

=head2 add_preload

    my $meeting = Elive::Entity::Meeting->retrieve($meeting_id);
    $meeting->add_preload($preload_id);

Associate a preload with a meeting

=head3 See also

    Elive::Entity::Preload

=cut

sub add_preload {
    my $self = shift;
    my %opt = @_;

    my $meeting_id = $opt{meeting_id};
    $meeting_id ||= $self->meetingId
	if ref($self);

    die "Unable to determine meeting_id"
	unless $meeting_id;

    my $preload_id = $opt{preload_id};

    die "unabe to determine prelod_id"
	unless $preload_id;


    my $adapter = $self->check_adapter('addMeetingPreload');

    my $som = $self->connection->call($adapter,
				      meetingId => $meeting_id,
				      preloadId => $preload_id,
	);

    $self->_check_for_errors($som);
}

sub _freeze {
    my $class = shift;
    my $data = shift;
    #
    # facilitor -> facilitatorId
    #
    my $frozen = $class->SUPER::_freeze($data, @_);

    if (my $facilitatorId = delete $frozen->{facilitatorId}) {
	$frozen->{facilitator} =  $facilitatorId;
    }

    return $frozen;
}

sub _readback_check {
    my $class = shift;
    my %updates = %{shift()};

    #
    # password not included in readback record - skip it
    #

    delete $updates{password};

    $class->SUPER::_readback_check(\%updates, @_);
}

sub _thaw {
    my $class = shift;
    my $db_data = shift;
    my $data = $class->SUPER::_thaw($db_data, @_);

    if ($data->{Adapter}) {
	#
	# meeting giving us unexpected Adapter property. Turf it
	#

	if ($class->debug) {
	    print STDERR "Stray meeting adaptor found:\n";
	    print STDERR YAML::Dump($data->{Adapter});
	    print STDERR "\n";
	}
	
	delete $data->{Adapter};
    }

    return $data;
}

=head1 BUGS & LIMITATIONS

Seems that privateMeeting gets ignored on update for Elluminate Live 9 & 9.1.
If you try to set it the readback check may fail.

=cut

1;
