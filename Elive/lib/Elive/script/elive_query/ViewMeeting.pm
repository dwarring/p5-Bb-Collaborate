package Elive::script::elive_query::ViewMeeting;
use warnings; use strict;
use Mouse;

use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;

use base 'Elive::Entity::Meeting';

=head1 DESCRIPTION

Support class for C<elive_query> Composite view of Meetings, ServerParameters
and Meeting parameters classes.

=cut

sub _init {

    no strict 'refs';

    *{properties} = sub {Elive::Entity::Meeting->properties};
    *{property_types} = sub {Elive::Entity::Meeting->property_types};

    *{derivable} = sub {
	my $class = shift;

	my %derivable = (
	    Elive::Entity::Meeting->derivable,

	    (map {$_ => $_} Elive::Entity::ServerParameters->properties),
	    Elive::Entity::ServerParameters->derivable,

	    (map {$_ => $_} Elive::Entity::MeetingParameters->properties),
	    Elive::Entity::MeetingParameters->derivable,
	    );

	return %derivable;
    };

    my %delegates = (
	'Elive::Entity::ServerParameters' => '_cache_server_parameters',
	'Elive::Entity::MeetingParameters' => '_cache_meeting_parameters',
	);

    foreach my $delegate_class (sort keys %delegates) {

	my $cache_accessor = $delegates{ $delegate_class };

	my %methods = ($delegate_class->derivable,
		       map {$_ => $_} $delegate_class->properties);

	foreach my $alias (keys %methods) {

	    next if $alias eq 'meetingId';
	    my $method = $methods{$alias};

	    my $delegate_subref = $delegate_class->can($method);

	    my $subref = sub {
		my $self = shift;

		$self->{$cache_accessor} ||=  $delegate_class->retrieve( $self->meetingId, reuse => 1, connection => $self->connection);
	    
		$self->{$cache_accessor}->$method(@_);
	    };

	    *{$alias} = $subref;
	}
    }
}

1;
