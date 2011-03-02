package Elive::View::Session;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Struct';

use Elive::DAO;
use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ParticipantList;

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');
__PACKAGE__->_alias(meetingId => 'id');
__PACKAGE__->_alias(sessionId => 'id');

has 'meeting' => (is => 'rw', isa => 'Elive::Entity::Meeting', coerce => 1);
has 'server_parameters' => (is => 'rw', isa => 'Elive::Entity::ServerParameters', coerce => 1);
has 'meeting_parameters' => (is => 'rw', isa => 'Elive::Entity::MeetingParameters', coerce => 1);
has 'participant_list' => (is => 'rw', isa => 'Elive::Entity::ParticipantList', coerce => 1);

=head1 NAME

Elive::View::Session - Session view class

=head1 DESCRIPTION

This class provides a view of a meeting as 'join' of meetings, meeting
participants, server parameters and participants. This is primary to provide
a session view for L<elive_query>. 

The C<list> method requires secondary fetches and is fairly slow.

=back

=cut

sub properties {
    my $class = shift;

    my %seen = (meetingId => 1);

    my @all_properties = grep {! $seen{$_}++} (
	'id',
	Elive::Entity::Meeting->properties,
	Elive::Entity::MeetingParameters->properties,
	Elive::Entity::ServerParameters->properties,
	Elive::Entity::ParticipantList->properties,
    );

    return @all_properties;
}

sub property_types {
    my $class = shift;

    my $id = $class->SUPER::property_types->{id};

    my %property_types = (
	id => $id,
	%{ Elive::Entity::ParticipantList->property_types },
	%{ Elive::Entity::ServerParameters->property_types },
	%{ Elive::Entity::MeetingParameters->property_types },
	%{ Elive::Entity::Meeting->property_types },
    );

    delete $property_types{meetingId};

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

do {

    #flatten out all the properties accessors

    no strict 'refs';

     my %delegates = (
	 'Elive::Entity::Meeting' => 'meeting',
	 'Elive::Entity::ServerParameters' => 'server_parameters',
	 'Elive::Entity::MeetingParameters' => 'meeting_parameters',
	 'Elive::Entity::ParticipantList' => 'participant_list',
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
