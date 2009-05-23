package Elive::Entity::Meeting;
use warnings; use strict;

use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

use Elive::Util;
use Elive::Entity::Preload;

=head1 NAME

Elive::Entity::Meeting - Elluminate Meeting instance class

=head1 DESCRIPTION

This is the main entity for meetings.

Note that there are additional meeting settings contained in both
Elive::Entity::MeetingParameters and Elive::Entity::ServerParameters.

=cut

__PACKAGE__->entity_name('Meeting');
__PACKAGE__->collection_name('Meetings');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'meeting name',
    );

has 'start' => (is => 'rw', isa => 'HiResDate', required => 1,
		documentation => 'meeting start time');

has 'end' => (is => 'rw', isa => 'HiResDate', required => 1,
	      documentation => 'meeting end time');

has 'password' => (is => 'rw', isa => 'Str',
		   documentation => 'meeting password');

has 'deleted' => (is => 'rw', isa => 'Bool');

has 'facilitatorId' => (is => 'rw', isa => 'Str',
			documentation => 'userId of facilator');

has 'privateMeeting' => (is => 'rw', isa => 'Bool',
			 documentation => "don't display meeting in public schedule");

=head1 METHODS

=cut

=head2 insert

=head3 synopsis

    #
    # Simple case, single meeting
    #
    my $meeting = Elive::Entity::Meeting->insert({
        start => time,
        end => time,
        name => string,
        password => string,
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

sub insert {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my %params = (seats => 'Int',
		  recurrenceCount => 'Int',
		  recurrenceDays => 'Int',
		  timeZone => 'Str');

    foreach (keys %params) {
	my $type = $params{$_};
	#
	# these are parameters, not properties
	#
	$opt{param}{$_} = Elive::Util::_freeze(delete $data->{$_}, $type)
	    if exists $data->{$_}
    }

    $class->SUPER::insert($data, %opt);
}

=head2 update

=head3 synopsis

    my $meeting = Elive::Entity::Meeting->update({
        start => time,
        end => time,
        name => string,
        password => string,
        seats => int,
        privateMeeting => 0|1,
        timeZone => string
       });

=cut

sub update {
    my $self = shift;
    my $data = shift;
    my %opt = @_;

    my %params = (seats => 'Int',
		  timeZone => 'Str');

    foreach (keys %params) {
	my $type = $params{$_};
	#
	# these are parameters, not properties
	#
	$opt{param}{$_} = Elive::Util::_freeze(delete $data->{$_}, $type)
	    if exists $data->{$_}
    }

    $self->SUPER::update($data, %opt);
}

=head2 list_user_meetings_by_date

List all meetings over a given date range.

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
    [$user_id, $now->epoch.'000', $next_week->epoch.'000']
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

    my %fetch_params;
    $fetch_params{userId} = Elive::Util::_freeze(shift @$params,'Str');
    @fetch_params{qw{startDate endDate}}
    = map {my $d = Elive::Util::_freeze($_,'HiResDate')} @$params; 

    my $adapter = $class->check_adapter('listUserMeetingsByDate');

    return $class->_fetch(\%fetch_params,
			  adapter => $adapter,
			  %opt,
	);
}

=head2 web_url

Utility method to return various website links for the meeting. This is
available as both class level and object level methods.

=head3 Examples

    #
    # Class level access.
    #
    my $url = Elive::Entity::Meeting->web_url(
                     meeting_id => $meeting_id,
                     action => 'join',    # join|edit|...
                     connection => $my_connection);  # optional


    #
    # Object level.
    #
    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $url = meeting->web_url(action => 'join');

=cut

sub web_url {
    my $self = shift;
    my %opt = @_;

    my $meeting_id = $opt{meeting_id};
    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    if (ref($self)) {
	#
	# dealing with an object
	#
	$meeting_id ||= $self->meetingId;
    }
    elsif (ref($meeting_id)) {  # an object
	$meeting_id = $meeting_id->meetingId;
    }

    die "no meeting_id given"
	unless $meeting_id;

    my $url = $connection->url;

    my %Actions = (
	'join'   => '%s/join_meeting.html?meetingId=%s',
	'edit'   => '%s/modify_meeting.event?meetingId=%s',
	'delete' => '%s/delete_meeting?meetingId=%s',
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

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $som = $connection
	->call($adapter,
	       meetingId => Elive::Util::_freeze($meeting_id, 'Int'),
	       preloadId => Elive::Util::_freeze($preload_id, 'Int'),
	);

    $self->_check_for_errors($som);
}

=head2 check_preload

my $ok = $meeting_obj->check_preload($preload);

Checks that the preload is associated with this meeting.

=cut

sub check_preload {
    my $self = shift;
    my $preload_id = shift;
    my %opt = @_;

    $preload_id = $preload_id->preloadId
	if ref($preload_id);

    my $adapter = $self->check_adapter('checkMeetingPreload');

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $som = $connection
	->call($adapter,
	       preloadId => Elive::Util::_freeze($preload_id, 'Int'),
	       meetingId => Elive::Util::_freeze($self->meetingId, 'Int'),
	       );

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Bool');
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
    # to do: check for correct sequence of start and end times.
    # for now, we just check the first meeting.
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

=head2 remove_preload

    $meeting_obj->remove_preload($preload_id_or_obj);

Remove a particular preload from the meeting.

Note that the preload object is not actually deleted, just disassociated
from the meeting and will continue to exist as a resource on the server.

You don't need to call this method if you simply intend to delete the
preload. This system will remove it from any meetings for you.

=cut

sub remove_preload {
    my $self = shift;
    my $preload_id = shift;
    my %opt = @_;

    my $meeting_id = $self->meetingId;

    die 'unable to get a meeting_id'
	unless $meeting_id;

    $preload_id = $preload_id->preloadId
	if ref($preload_id);

    die 'unable to get a preload_id'
	unless $preload_id;

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $adapter = $self->check_adapter('deleteMeetingPreload');

    my $som = $connection->call($adapter,
				meetingId => Elive::Util::_freeze($meeting_id, 'Int'),
				preloadId => Elive::Util::_freeze($preload_id, 'Int'),
				);

    $self->_check_for_errors($som);
}
    

=head2 buildJNLP 

    my $jnlp = $meeting_entity->buildJNLP(version => version,
					  user => userId|userName,
					  pass => password);

Builds a JNLP for the meeting.

JNLP is the 'Java Network Launch Protocol', also commonly known as Java
WebStart. You can render this as a web page with mime type
C<application/x-java-jnlp-file>.

Under Windows, and other desktops, you can save this to a file with extension
C<JNLP>.

See also L<http://en.wikipedia.org/wiki/JNLP>.

=cut

sub buildJNLP {
    my $self = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $meeting_id = $opt{meeting_id};

    $meeting_id ||= $self->meetingId
	if ref($self);

    die "unable to determine meeting_id"
	unless $meeting_id;

    my %soap_params = (meetingId => $meeting_id);

    foreach my $param (qw(version password)) {
	my $val = delete $opt{$param};
	$soap_params{$param} = Elive::Util::_freeze($val, 'Str')
	    if $val;
    }

    for (delete $opt{user} || $connection->login->userId) {

	$soap_params{m{^\d+$}? 'userId' : 'userName'} = Elive::Util::_freeze($_, 'Str');
    }

    my $adapter = $self->check_adapter('buildMeetingJNLP');

    my $som = $connection->call($adapter,
				%soap_params,
				);

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Str');
}

=head2 list_preloads

    my $preloads = $meeting_obj->list_preloads;

Lists all preloads associated with the meeting.

=cut

sub list_preloads {
    my $self = shift;

    return Elive::Entity::Preload
	->list_meeting_preloads($self->meetingId,@_);
}
    
=head1 SEE ALSO

Elive::Entity::Preload
Elive::Entity::MeetingParameters 
Elive::Entity::ServerParameters

=cut

1;
