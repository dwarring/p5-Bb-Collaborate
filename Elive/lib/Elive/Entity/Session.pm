package Elive::Entity::Session;
use warnings; use strict;

use Class::Data::Inheritable;
use base 'Class::Data::Inheritable';
BEGIN {
    __PACKAGE__->mk_classdata(_response_handler => 'Elive::Entity::Session::Base');
}

use Mouse;
use Mouse::Util::TypeConstraints;

extends __PACKAGE__->_response_handler;

=head1 NAME

Elive::Entity::Session - Elluminate Session entity class

=head1 DESCRIPTION

** This class in under construction **

The Command Toolkit includes C<createSession> and C<updateSession>.

These are alternate commands for setting up meetings and associated entities,
including meeting, server details, meeting parameters and participants.

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

sub _process_results {
    my ($class, $soap_results, %opt) = @_;
    # delegate to our underlying handler class
    return $class->_response_handler->_process_results( $soap_results, %opt );
}

1;
