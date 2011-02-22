package Elive::Entity::Session;
use warnings; use strict;
use Mouse;

use Class::Accessor;

use Elive::Entity;
use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;

use base 'Elive::Entity';
use base 'Class::Accessor';

__PACKAGE__->mk_classdata('meeting');
__PACKAGE__->mk_classdata('server_parameters');
__PACKAGE__->mk_classdata('meeting_parameters');
__PACKAGE__->mk_classdata('participants');

=head1 DESCRIPTION

** This class in under construction **

The Command Toolkit includes C<createSession> and C<updateSession>.

These are alternate commands for setting up meetings and associated entities,
including meeting, server details, meeting parameters and participants.

Some meeting properties can only be supported through the session view,
including restricted meetings, redirect Urls and groups of participants.

=cut

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

__PACKAGE__->_alias(allPermissions => 'fullPermissions', class => 'Elive::Entity::ServerParameters', freeze => 1);
__PACKAGE__->_alias(facilitator => 'facilitatorId', class => 'Elive::Entity::Meeting', freeze => 1);

sub retrieve {
    my $class = shift;
    my $id = shift;
    my %opt = @_;
    ($id) = @$id if ref($id);
    my $self = $class->new({meetingId => $id});

    for ($opt{connection}) {
	$self->connection($_) if $_;
    }

    return $self;
}

sub list {
    my $class = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection
	or die "not connected";
    my $meetings = Elive::Entity::Meeting->list(%opt);

    my @sessions = map {
	my $meeting = $_;

	my $self = $class->new({meetingId => $meeting->meetingId});
	$self->meeting($meeting);
	$self->connection($connection);

	$self;
    } @$meetings;

    return \@sessions;
}

sub properties {
    my $class = shift;
    my %seen;
    my @all_properties = grep {! $seen{$_}++} (
	Elive::Entity::Meeting->properties,
	Elive::Entity::MeetingParameters->properties,
	Elive::Entity::ServerParameters->properties,
	Elive::Entity::ParticipantList->properties,
    );

    return @all_properties;
}

sub property_types {
    my $class = shift;

    my %property_types = (
	%{ Elive::Entity::ParticipantList->property_types },
	%{ Elive::Entity::ServerParameters->property_types },
	%{ Elive::Entity::MeetingParameters->property_types },
	%{ Elive::Entity::Meeting->property_types },
    );

    return \%property_types;
}

sub derivable {
    my $class = shift;
    return (
	Elive::Entity::Meeting->derivable,
	Elive::Entity::MeetingParameters->derivable,
	Elive::Entity::ServerParameters->derivable,
	Elive::Entity::ParticipantList->derivable,
	);
}

sub is_changed {
    my $self = shift;

    return (
	($self->meeting? $self->meeting->is_changed : ()),
	($self->meeting_parameters? $self->meeting_parameters->is_changed : ()),
	($self->server_parameters? $self->server_parameters->is_changed : ()),
	($self->participants? $self->participants->is_changed : ()),
	);
}

sub _process_results {
    my ($class, $soap_results, %opt) = @_;
    use YAML; die YAML::Dump {_process_results_tba => {results => $soap_results, opt => \%opt}};

    my %expected = (
	MeetingAdapter => 'Elive::Entity::Meeting',
	MeetingParameterAdapter => 'Elive::Entity::MeetingParameters',
	ServerParametersAdapter => 'Elive::Entity::ServerParameters',
	ParticipantListAdapter => 'Elive::Entity::ParticipantList',
	);

    # the invited guests are oddly seperated from other participants

    my %data;
}

do {

    #flatten out all the properties accessors

    no strict 'refs';

     my %delegates = (
	'Elive::Entity::Meeting' => 'meeting',
	'Elive::Entity::ServerParameters' => 'server_parameters',
	'Elive::Entity::MeetingParameters' => 'meeting_parameters',
	);

    foreach my $delegate_class (sort keys %delegates) {

	my $cache_accessor = $delegates{ $delegate_class };

	my %methods = ($delegate_class->derivable,
		       map {$_ => $_} $delegate_class->properties);

	foreach my $alias (keys %methods) {

	    next if $alias eq 'meetingId';

	    my $method = $methods{$alias};

	    die "class $delegate_class can't $method"
		unless $delegate_class->can($method);

	    my $subref = sub {
		my $self = shift;

		$self->{$cache_accessor} ||=  $delegate_class->retrieve( $self->meetingId, reuse => 1, connection => $self->connection);
	    
		$self->{$cache_accessor}->$method(@_);
	    };

	    *{$alias} = $subref;
	    *{$method} = $subref
		unless $method eq $alias;
	}
    }
};

1;
