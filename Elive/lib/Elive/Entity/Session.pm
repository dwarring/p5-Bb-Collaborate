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

=head1 DESCRIPTION

** This class in under construction **

The Command Toolkit includes C<createSession> and C<updateSession>.

A session is view or compositve class that encompasses Meetings, ServerParameters, Meeting Parameters and Participsants.

Importantly, some meeting properties can only be supported through the session
view, including restricted meetings, redirect Urls and groups of participants.

=cut

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

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

    my $meetings = Elive::Entity::Meeting->list(@_);
    my @sessions;

    foreach my $meeting (@$meetings) {
	my $self = $class->new({meetingId => $meeting->meetingId});
	$self->{_cache_meeting} = $meeting;
	for ($opt{connection}) {
	    $self->connection($_) if $_;
	}
	push (@sessions, $self);

    }
    return \@sessions;
}

sub properties {
    my $class = shift;
    my %seen;
    my @all_properties = grep {! $seen{$_}++} (
	Elive::Entity::Meeting->properties,
	Elive::Entity::MeetingParameters->properties,
	Elive::Entity::ServerParameters->properties,
    );

    return @all_properties;
}

sub property_types {
    my $class = shift;

    my %property_types = (
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

1;
