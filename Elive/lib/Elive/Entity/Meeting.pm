package Elive::Entity::Meeting;
use warnings; use strict;

use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

=head1 NAME

Elive::Entity::Meeting - Elluminate Meeting instance class

=head1 DESCRIPTION

This is the main entity for meetings.

Note that there are additional metting settings contained in both
Elive::Entity::MeetingParameters and Elive::Entity::ServerParameters.

=cut

__PACKAGE__->entity_name('Meeting');
__PACKAGE__->collection_name('Meetings');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

has 'password' => (is => 'rw', isa => 'Str',
		   documentation => 'meeting password (optional)');

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

=head2 insert

=head3 synopsis

    #
    # Simple case, single meeting
    #
    my $meeting = Elive::Entity::Meeting->insert({
        start => hires_time,
        end => hires_time,
        name => string,
        password =. string,
        seats => int,
        privateMeeting => 0|1,
        timeZone => string
       });

    #
    # A recurring series of meetings:
    #
    my @meetings = Elive::Entity::Meeting->insert({
                            ...,
                            recurrenceCount => n,
                            recurrenceDays => 7,
                        });

=cut

sub _insert_class {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    foreach (qw(seats recurrenceCount recurrenceDays timeZone)) {
	$opt{param}{$_} = delete $data->{$_}
	    if exists $data->{$_}
    }

    $class->SUPER::_insert_class($data, %opt);
}

=head2 update

=head3 synopsis

    my $meeting = Elive::Entity::Meeting->update({
        start => hires_time,
        end => hires_time,
        name => string,
        password =. string,
        seats => int,
        privateMeeting => 0|1,
        timeZone => string
       });

=cut

sub update {
    my $self = shift;
    my $data = shift;
    my %opt = @_;

    warn YAML::Dump({meeting_update_data => $data})
	if (Elive->debug);

    foreach (qw(seats timeZone)) {
	$opt{param}{$_} = delete $data->{$_}
	    if exists $data->{$_}
    }

    $self->SUPER::update($data, %opt);
}

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

=head2 web_url

Utility method to return various website url's for the meeting. This is
available as both class level and object level methods.

=head3 Examples

    #
    # Class level access. This may save an unecessary fetch.
    #
    my $url = Elive::Entity::Meeting->meeting_url(
                     meeting_id => $meeting_id,
                     action => 'join',    # join|edit|...
                     connection => $my_connection);  # optional


    #
    # Object level.
    #
    my $meeting = Elive::Entity::Meeting->retrieve($meeting_id);
    my $url = meeting->web_url(action => 'join');

=cut

sub web_url {
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
    my $preload = shift;
    my %opt = @_;

    die 'usage: $meeting_obj->add_preload($preload || $preload_id)'
	unless $preload;

    my $meeting_id = $opt{meeting_id};

    $meeting_id ||= $self->meetingId
	if ref($self);

    die "unable to determine meeting_id"
	unless $meeting_id;

    my $preload_id = ref($preload)
	? $preload->preloadId
	: $preload;

    die "unable to determine preload_id"
	unless $preload_id;

    my $adapter = $self->check_adapter('addMeetingPreload');

    my $som = $self->connection->call($adapter,
				      meetingId => $meeting_id,
				      preloadId => $preload_id,
	);

    $self->_check_for_errors($som);
}

=head2 check_preload

my $ok = Elive::Entity::Meeting->check_preload($preload);

Checks that the preload is associated with ths meeting.

=cut

sub check_preload {
    my $self = shift;
    my $preload_id = shift;
    my %opt = @_;

    $preload_id = $preload_id->preloadId
	if ref($preload_id);

    my $adapter = $self->check_adapter('checkMeetingPreload');

    my $som =  $self->connection->call($adapter,
				       preloadId => $preload_id,
				       meetingId => $self->meetingId);

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && $results->[0] eq 'true';
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

    if (defined(my $privateMeeting = delete $frozen->{privateMeeting})) {
	$frozen->{private} =  $privateMeeting;
    }

    return $frozen;
}

sub _readback_check {
    my $class = shift;
    my %updates = %{shift()};
    my $rows = shift;

    #
    # password not included in readback record - skip it
    #

    delete $updates{password};

    #
    # A series of recurring meetings can potentially be returned.
    # to do: would be to check for correct ascension of start and
    # end times. 
    # just lop it for now
    #
    $rows = [$rows->[0]] if @$rows > 1;

    $class->SUPER::_readback_check(\%updates, $rows, @_);
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

=head1 SEE ALSO

Elive::Entity::Preload
Elive::Entity::MeetingParameters 
Elive::Entity::ServerParameters

=cut

1;
