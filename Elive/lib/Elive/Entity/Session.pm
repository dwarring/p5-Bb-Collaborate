package Elive::Entity::Session;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Carp;

extends 'Elive::Entity';

use Elive::Entity::Meeting;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ServerParameters;
use Elive::Entity::ParticipantList;

=head1 NAME

Elive::Entity::Session - ELM 3.x Session insert/update support (EXPERIMENTAL)

=head1 DESCRIPTION

** EXPERIMENTAL ** and ** UNDER CONSTRUCTION **

This support class assists with the freezing and thawing of parameters for
the C<createSession> and C<updateSession> commands.

These commands were introduced with Elluminate 3.0, they more-or-less replace
a series of meeting setup commands including: C<createMeeting> C<updateMeeting>,
C<updateMeetingParameters>, C<updateServerParameters>, C<setParticipantList> and
others.

Some of the newer features and more advanced session setup can only be acheived
via these newer commands.

=cut

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');
__PACKAGE__->_alias(meetingId => 'id');
__PACKAGE__->_alias(sessionId => 'id');

__PACKAGE__->mk_classdata('_delegates');

__PACKAGE__->_delegates({
    meeting => 'Elive::Entity::Meeting',
    meetingParameters => 'Elive::Entity::MeetingParameters',
    serverParameters => 'Elive::Entity::ServerParameters',
    participantList => 'Elive::Entity::ParticipantList',
    });

sub _delegate {
    my $pkg = shift;

    our %handled = (meetingId => 1);
    my $delegates = $pkg->_delegates;

    foreach my $prop (sort keys %$delegates) {
	my $class = $delegates->{$prop};
	my $aliases = $class->_get_aliases;
	my @delegates = grep {!$handled{$_}++} ($class->properties, $class->derivable, sort keys %$aliases);
	push (@delegates, qw{buildJNLP check_preload add_preload remove_preload is_participant is_moderator list_preloads list_recordings})
	    if $prop eq 'meeting';
	has $prop
	    => (is => 'rw', isa => $class, coerce => 1,
		handles => \@delegates,
		lazy => 1,
		default => sub {$class->retrieve($_[0]->id, copy => 1, connection => $_[0]->connection)},
	    );
    }
}

__PACKAGE__->_delegate;

__PACKAGE__->_alias(reservedSeatCount => 'seats', freeze => 1);
__PACKAGE__->_alias(restrictParticipants => 'restrictedMeeting', freeze => 1);

## ELM 3.x mappings follow

=head2 invitedParticipantsList

=cut

sub invitedParticipantsList {
    my $self = shift;
    die 'tba - invitedParticipantsList';
}

=head2 invitedModerators

=cut

sub invitedModerators {
    my $self = shift;
    die 'tba - invitedModerators';
}

=head2 invitedGuests

=cut

sub invitedGuests {
    my $self = shift;
    die 'tba - invitedGuests';
}

__PACKAGE__->_alias(boundaryTime => 'boundaryMinutes', freeze => 1);

__PACKAGE__->_alias(supervisedMeeting => 'supervised', freeze => 1);

__PACKAGE__->_alias(allPermissionsMeeting => 'fullPermissions', freeze => 1);

__PACKAGE__->_alias(sessionServerTeleconferenceType => 'telephonyType', freeze => 1);

__PACKAGE__->_alias(enableTeleconferencing => 'enableTelephony', freeze => 1);

__PACKAGE__->_alias(facilitator => 'facilitatorId', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferenceAddress => 'moderatorTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferencePIN => 'moderatorTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(participantTeleconferenceAddress => 'participantTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(participantTeleconferencePIN => 'participantTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(serverTeleconferenceAddress => 'serverTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(serverTeleconferencePIN => 'serverTelephonyPIN', freeze => 1);

sub _alias {
    my ($entity_class, $from, $to, %opt) = @_;

    $from = lcfirst($from);
    $to = lcfirst($to);

    die 'usage: $entity_class->_alias(alias, prop, %opts)'
	unless ($entity_class

		&& $from && !ref($from)
		&& $to && !ref($to));

    my $aliases = $entity_class->_get_aliases;

    #
    # Set our entity name. Register it in our parent
    #
    die "$entity_class: attempted redefinition of alias: $from"
	if $aliases->{$from};

    die "$entity_class: can't alias $from it's already a property!"
	if $entity_class->property_types->{$from};

# get this test working
##    die "$entity_class: attempt to alias $from to non-existant property $to - check spelling and declaration order"
##	unless $entity_class->property_types->{$to};

    $opt{to} = $to;
    $aliases->{$from} = \%opt;

    return \%opt;
}

sub _data_owned_by {
    my $class = shift;
    my $delegate_class = shift;
    my @props = @_;

    my %owns = (%{ $delegate_class->property_types },
		%{ $delegate_class->_aliases },
		$delegate_class->params);

    return grep { exists $owns{$_} } @props;
}

sub set {
    my $self = shift;
    my %data = @_;

    my $delegates = $self->_delegates;

    foreach my $delegate (sort keys %$delegates) {

	my $delegate_class = $delegates->{$delegate};
	my @delegate_props = $self->_data_owned_by($delegate_class => sort keys %data);
	my %delegate_data =  map {$_ => delete $data{$_}} @delegate_props;

	$delegate_class->set( %delegate_data );
    }

    carp 'unknown session attributes '.join(' ', sort keys %data).'. expected: '.join(' ', sort $self->properties)
	if keys %data;

    return $self;
}

# The createSession and updateSession accept a flatten list, hence
# freezing also involves flattening the list. 

sub _freeze {
    my $class = shift;
    my %data = %{ shift() };
    my %opts = @_;

    my $delegates = $class->_delegates;

    my %frozen = map {
	my $delegate = $_;
	my $delegate_class = $delegates->{$delegate};
	my @delegate_props = $class->_data_owned_by($delegate_class => sort keys %data);

	#
	# accept flattened or unflattened data: eg $data{meeting}{start} or $data{start}

	my %delegate_data = (
	    %{ $data{$delegate} || {}},
	    map {$_ => delete $data{$_}} @delegate_props
	    );

	%{ $delegate_class->_freeze (\%delegate_data, canonical => 1) };
    } (sort keys %$delegates);

    if (my $id = delete $data{id}) {
	$frozen{id} = Elive::Util::_freeze( $id, 'Int' );
    }

    $class->__apply_freeze_aliases( \%frozen )
	unless $opts{canonical};

    # todo lots more tidying and construction

    return \%frozen;
}

=head2 insert

Create a new session using the C<createSession> command

=cut

# this is a real jumble at the moment, lots of refactoring required

sub _unpack_as_list {
    my $class = shift;
    my $data = shift;

    my $results_list = $class->SUPER::_unpack_as_list($data);
    # a bit iffy
    my %results ;
    @results{qw{meeting serverParameters meetingParameters participantList}} = @$results_list;

    $results{Id} = $results{meeting}{MeetingAdapter}{Id};

##    die YAML::Dump {results => \%results};

    # todo: recurring meetings
    return [\%results]
}

sub insert {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection
	or die "not connected";

    my $preloads = delete $data->{add_preload};

    # lots to be done!

    die "don't yet support preloads" if $preloads;
    die "don't yet support participants" if $data->{participants};
    die "don't yet support recurring meetings"
	if $data->{recurrenceCount} || $data->{recurrenceDays};

    return $class->SUPER::insert( $data, command => 'createSession', %opt );

=for disposal

    my $frozen_data = $class->_freeze( $data );

    use YAML; warn YAML::Dump {raw => $data, frozen => $frozen_data};

    my $som = $connection->call(createSession => %$frozen_data);
    $connection->_check_for_errors( $som );

    warn YAML::Dump {results => \%results};
    my $results_processed = $class->_process_results(  );

    # not able to construct or an object yet - just dump
    use YAML;
    warn YAML::Dump {processed => $results_processed};
    die "tba working elm3 insert";

=cut
}

=head2 retrieve

Retrieves a session for the given session id.

    Elive::Entity::Session->retrieve( $session_id );

=cut

sub retrieve {
    my $class = shift;
    my $id = shift;
    my %opt = @_;
    ($id) = @$id if ref($id);
    my $self = bless {id => Elive::Util::string($id)}, $class;

    for ($opt{connection}) {
	$self->connection($_) if $_;
    }

    return $self;
}

=head2 list

List all sessions that match a given critera:

    my $sessions = Elive::Entity::Session->list( filter => "(name like '*Sample*')" );

=cut

sub list {
    my $class = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection
	or die "not connected";
    my $meetings = Elive::Entity::Meeting->list(%opt);

    my @sessions = map {
	my $meeting = $_;

	my $self = bless {id => $meeting->meetingId}, $class;
	$self->meeting($meeting);
	$self->connection($connection);

	$self;
    } @$meetings;

    return \@sessions;
}

=head2 delete

Deletes an expired or unwanted session from the Elluminate server.

    my $session = Elive::Entity::Session->retrieve( $session_id );
    $session->delete;

=cut

sub delete {
    my $self = shift;
    my %opt = @_;

    $self->meeting->delete;
    my $delegates = $self->_delegates;

    foreach my $delegate (sort keys %$delegates) {
	$self->$delegate->_deleted(1) if $self->{$delegate};
    }

    return 1;
}

1;
