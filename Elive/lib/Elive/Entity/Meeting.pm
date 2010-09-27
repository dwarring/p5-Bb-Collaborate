package Elive::Entity::Meeting;
use warnings; use strict;

use Mouse;

extends 'Elive::Entity';

use Elive::Util;
use Elive::Entity::Preload;
use Elive::Entity::Recording;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ServerParameters;
use Elive::Entity::ParticipantList;

use YAML;

=head1 NAME

Elive::Entity::Meeting - Elluminate Meeting instance class

=head1 DESCRIPTION

This is the main entity class for meetings.

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
			documentation => 'userId of facilitator');
__PACKAGE__->_alias(facilitator => 'facilitatorId', freeze => 1);

has 'privateMeeting' => (is => 'rw', isa => 'Bool',
			 documentation => "don't display meeting in public schedule");
__PACKAGE__->_alias(private => 'privateMeeting', freeze => 1);

has  'allModerators' => (is => 'rw', isa => 'Bool',
			 documentation => "all participants can moderate");

has  'restrictedMeeting' => (is => 'rw', isa => 'Bool',
			     documentation => "Restricted meeting");

has 'adapter' => (is => 'rw', isa => 'Str',
		  documentation => 'adapter used to create the meeting/session');

=head1 METHODS

=cut

=head2 insert

    my $start = time() + 15 * 60; # starts in 15 minutes
    my $end   = $start + 30 * 60; # runs for half an hour

    my $meeting = Elive::Entity::Meeting->insert({
	 name              => 'Test Meeting',
	 facilitatorId     => Elive->login,
	 start             => $start . '000',
	 end               => $end   . '000',
         password          => 'secret!',
         privateMeeting    => 1,
         restrictedMeeting => 1,
         seats             => 42,
	 });

    #
    # Set the meeting participants
    #
    my $participant_list = $meeting->participant_list;
    $participant_list->participants([qw(smith jones)]);
    $participant_list->update;

A series of meetings can be created using the C<recurrenceCount> and
C<recurrenceDays> parameters.

    #
    # create three weekly meetings
    #
    my @meetings = Elive::Entity::Meeting->insert({
                            ...,
                            recurrenceCount => 3,
                            recurrenceDays  => 7,
                        });
=cut

sub insert {
    my ($class, $data, %opt) = @_;

    die "usage: $class->insert(\\%data, %opts)"
	unless (Elive::Util::_reftype($data) eq 'HASH');
 
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

    return $class->SUPER::insert($data, %opt);
}

=head2 update

    my $meeting = Elive::Entity::Meeting->update({
        start             => hires-date,
        end               => hires-date,
        name              => string,
        password          => string,
        seats             => int,
        privateMeeting    => 0|1,
        restrictedMeeting => 0|1,
        timeZone          => string
       });

=cut

sub update {
    my ($self, $update_data, %opt) = @_;

    my %params = (seats => 'Int',
		  timeZone => 'Str');

    foreach (keys %params) {
	my $type = $params{$_};
	#
	# these are parameters, not properties
	#
	$opt{param}{$_} = Elive::Util::_freeze(delete $update_data->{$_}, $type)
	    if exists $update_data->{$_}
    }

    return $self->SUPER::update($update_data, %opt);
}

=head2 delete

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    $meeting->delete

Delete the meeting.

Note:

=over 4

=item Meeting recordings are not deleted.

If you also want to remove the associated recordings, you'll need to delete
them yourself, E.g.:

    my $recordings = $meeting->list_recordings;

    foreach my $recording (@$recordings) {
        $recording->delete;
    }

    $meeting->delete;

=item With Elluminate 9.5 onwards simply sets the I<deleted> property to true.

Meetings, Meeting Parameters, Server Parameters and recordings remain
accessable via the SOAP inteface.

You'll need to remember to check for deleted meetings:

    my $meeting =  Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $is_live = $meeting->deleted;

or filter them out when listing meetings:

    my $live_meetings =  Elive::Entity::Meeting->list(filter => 'deleted = false');

=back

=cut

=head2 list_user_meetings_by_date

Lists all meetings for which this user is a participant, over a given
date range.

For example, to list all meetings for a particular user over the next week:

   my $now = DateTime->now;
   my $next_week = $now->clone->add(days => 7);

   my $meetings = Elive::Entity::Meeting->list_user_meetings_by_date(
        [$user_id, $now->epoch.'000', $next_week->epoch.'000']
       );
=cut

sub list_user_meetings_by_date {
    my ($class, $params, %opt) = @_;

    die 'usage: $class->user_meetings_by_date([$user, $start_date, $end_date])'
	unless (Elive::Util::_reftype($params) eq 'ARRAY'
		&& $params->[0] && @$params <= 3);

    my %fetch_params;
    $fetch_params{userId}    = Elive::Util::_freeze(shift @$params,'Str');
    $fetch_params{startDate} = Elive::Util::_freeze(shift @$params,'HiResDate');
    $fetch_params{endDate} = Elive::Util::_freeze(shift @$params,'HiResDate');

    my $adapter = $class->check_adapter('listUserMeetingsByDate');

    return $class->_fetch(\%fetch_params,
			  adapter => $adapter,
			  %opt,
	);
}

=head2 add_preload

    my $meeting = Elive::Entity::Meeting->retrieve($meeting_id);
    $meeting->add_preload($preload_id);

Associates a preload with a meeting. This preload must pre-exist in the
database.

=head3 See also

Elive::Entity::Preload

=cut

sub add_preload {
    my ($self, $preload_id, %opt) = @_;

    die 'usage: $meeting_obj->add_preload($preload || $preload_id)'
	unless $preload_id;

    my $meeting_id = $opt{meeting_id} || $self->meetingId;

    die "unable to determine meeting_id"
	unless $meeting_id;

    my $adapter = $self->check_adapter('addMeetingPreload');

    my $connection = $self->connection
	or die "not connected";

    my $som = $connection
	->call($adapter,
	       meetingId => Elive::Util::_freeze($meeting_id, 'Int'),
	       preloadId => Elive::Util::_freeze($preload_id, 'Int'),
	);

    return $self->_check_for_errors($som);
}

=head2 check_preload

    my $ok = $meeting_obj->check_preload($preload);

Checks that the preload is associated with this meeting.

=cut

sub check_preload {
    my ($self, $preload_id, %opt) = @_;

    die 'usage: $meeting_obj->check_preload($preload || $preload_id)'
	unless $preload_id;

    my $meeting_id = $opt{meeting_id} || $self->meetingId;

    die "unable to determine meeting_id"
	unless $meeting_id;

    my $adapter = $self->check_adapter('checkMeetingPreload');

    my $connection = $self->connection
	or die "not connected";

    my $som = $connection
	->call($adapter,
	       preloadId => Elive::Util::_freeze($preload_id, 'Int'),
	       meetingId => Elive::Util::_freeze($meeting_id, 'Int'),
	       );

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Bool');
}

=head2 is_participant

    my $ok = $meeting_obj->is_participant($user);

Checks that the user is a meeting participant.

=cut

sub is_participant {
    my ($self, $user, %opt) = @_;

    die 'usage: $meeting_obj->is_preload($user || $user_id)'
	unless $user;

    my $meeting_id = $opt{meeting_id} || $self->meetingId;

    die "unable to determine meeting_id"
	unless $meeting_id;

    my $adapter = $opt{adapter} || 'isParticipant';

    $self->check_adapter($adapter);

    my $connection = $self->connection
        or die "not connected";

    my $som = $connection
        ->call($adapter,
               userId => Elive::Util::_freeze($user, 'Str'),
               meetingId => Elive::Util::_freeze($meeting_id, 'Int'),
               );

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Bool');
}

=head2 is_moderator

    my $ok = $meeting_obj->is_moderator($user);

Checks that the user is a meeting moderator.

=cut

sub is_moderator {
    my ($self, $user, %opt) = @_;

    return $self->is_participant($user, %opt, adapter => 'isModerator');
}

sub _readback_check {
    my ($class, $updates_href, $rows, @args) = @_;
    my %updates = %$updates_href;

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

    return $class->SUPER::_readback_check(\%updates, $rows, @args);
}

=head2 remove_preload

    $meeting_obj->remove_preload($preload_obj);
    $preload_obj->delete;  # if you don't want it to hang around

Disassociate a preload from a meeting.

=cut

sub remove_preload {
    my ($self, $preload_id, %opt) = @_;

    my $meeting_id = $opt{meeting_id} || $self->meetingId;

    die 'unable to get a meeting_id'
	unless $meeting_id;

    die 'unable to get a preload'
	unless $preload_id;

    my $connection = $self->connection
	or die "not connected";

    my $adapter = $self->check_adapter('deleteMeetingPreload');

    my $som = $connection->call($adapter,
				meetingId => Elive::Util::_freeze($meeting_id, 'Int'),
				preloadId => Elive::Util::_freeze($preload_id, 'Int'),
				);

    return $self->_check_for_errors($som);
}
    
=head2 buildJNLP 

    # ...
    use Elive;
    use Elive::Entity::Meeting;

    use CGI;
    my $cgi = CGI->new;

    #
    # [authentication etc goes here] ...
    #

    my $jnlp = $meeting_entity->buildJNLP(version => $version,
					  user => $userId||$userName,
					  pass => $password,
                                          displayName => $displayName,
                                         );
    #
    # join this user to the meeting
    #

    print $cgi->header(-type       => 'application/x-java-jnlp-file',
                       -attachment => 'my-meeting.jnlp');

    print $jnlp;

Builds a JNLP for the meeting.

JNLP is the 'Java Network Launch Protocol', also commonly known as Java
WebStart. To launch the meeting you can, for example, render this as a web
page, or send email attachments  with mime type C<application/x-java-jnlp-file>.

Under Windows, and other desktops, files are usually saved  with extension
C<JNLP>.

See also L<http://en.wikipedia.org/wiki/JNLP>.

=cut

sub buildJNLP {
    my ($self, %opt) = @_;

    my $connection = $self->connection || $opt{connection}
	or die "not connected";

    my $meeting_id = $opt{meeting_id} ||= $self->meetingId;

    die "unable to determine meeting_id"
	unless $meeting_id;

    my %soap_params = (meetingId => $meeting_id);

    foreach my $param (qw(version password displayName)) {
	my $val = delete $opt{$param};
	$soap_params{$param} = Elive::Util::_freeze($val, 'Str')
	    if defined $val;
    }

    for (delete $opt{user} || $connection->login->userId) {

	$soap_params{m{^\d+$}x? 'userId' : 'userName'} = Elive::Util::_freeze($_, 'Str');
    }

    my $adapter = $self->check_adapter('buildMeetingJNLP');

    my $som = $connection->call($adapter,
				%soap_params,
				);

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Str');
}

=head2 web_url

Utility method to return various website links for the meeting. This is
available as both class level and object level methods.

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
    my ($self, %opt) = @_;

    my $meeting_id = $opt{meeting_id} || $self->meetingId;
    $meeting_id = Elive::Util::_freeze($meeting_id, 'Str');

   die "no meeting_id given"
	unless $meeting_id;

    my $connection = $self->connection || $opt{connection}
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

=head2 parameters

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $meeting_parameters = $meeting->parameters;

Utility method to return the meeting parameters associated with a meeting.
See also L<Elive::Entity::MeetingParameters>.

=cut

sub parameters {
    my ($self, @args) = @_;

    return Elive::Entity::MeetingParameters
	->retrieve([$self->meetingId],
		   reuse => 1,
		   connection => $self->connection,
		   @args,
	);
}

=head2 server_parameters

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $server_parameters = $meeting->server_parameters;

Utility method to return the server parameters associated with a meeting.
See also L<Elive::Entity::ServerParameters>.

=cut

sub server_parameters {
    my ($self, @args) = @_;

    return Elive::Entity::ServerParameters
	->retrieve([$self->meetingId],
		   reuse => 1,
		   connection => $self->connection,
		   @args,
	);
}

=head2 participant_list

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id]);
    my $participant_list = $meeting->participant_list;

Utility method to return the participant_list associated with a meeting.
See also L<Elive::Entity::ParticipantList>.

=cut

sub participant_list {
    my ($self, @args) = @_;

    return Elive::Entity::ParticipantList
	->retrieve([$self->meetingId],
		   reuse => 1,
		   connection => $self->connection,
		   @args,
	);
}

=head2 list_preloads

    my $preloads = $meeting_obj->list_preloads;

Lists all preloads associated with the meeting. See also L<Elive::Entity::Preload>.

=cut

sub list_preloads {
    my ($self, @args) = @_;

    return Elive::Entity::Preload
        ->list_meeting_preloads($self->meetingId,
				connection => $self->connection,
				@args);
}

=head2 list_recordings

    my $recordings = $meeting_obj->list_recordings;

Lists all recordings associated with the meeting. See also
L<Elive::Entity::Recording>.

=cut

sub list_recordings {
    my ($self, @args) = shift;

    return Elive::Entity::Recording
	->list(filter => 'meetingId = '.$self->meetingId,
	       connection => $self->connection,
	       @args);
}

=head1 BUGS AND LIMITATIONS

=over 4

=item

Meetings can not be set to restricted (as of Elluminate 9.7 - 10.0), nor
does the SDK respect the server default settings for restricted meetings.

Update: As of Elluminate 10.0.1, the restrictedMeeting property is inherited
from Preferences E<gt>E<gt> Session Defaults E<gt>E<gt> Restrict Meetings.

=back

=head1 SEE ALSO

=over 4

=item Elive::Entity::Preload

=item Elive::Entity::Recording

=item Elive::Entity::MeetingParameters 

=item Elive::Entity::ServerParameters

=item Elive::Entity::ParticipantList

=back

=cut

1;
