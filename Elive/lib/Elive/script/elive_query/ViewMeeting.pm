package Elive::script::elive_query::ViewMeeting;
use Mouse;

use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;

use base 'Elive::Entity::Meeting';

=head1 DESCRIPTION

Utility class for C<elive_query> Composite of Meeting ServerParameters and
Meeting parameters objects.

=cut

sub properties {
    return Elive::Entity::Meeting->properties;
}

sub property_types {
    return Elive::Entity::Meeting->property_types
}

sub derivable {
    my $class = shift;

    my %derivable = (
	Elive::Entity::Meeting->derivable,

	(map {$_ => $_} Elive::Entity::ServerParameters->properties),
	Elive::Entity::ServerParameters->derivable,

	(map {$_ => $_} Elive::Entity::MeetingParameters->properties),
	Elive::Entity::MeetingParameters->derivable,
	);

    return %derivable;
}

BEGIN {

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

	    no strict 'refs';

	    my $subref = sub {
		my $self = shift;

		$self->{$cache_accessor} ||=  $delegate_class->retrieve( $self->meetingId, reuse => 1);
	    
		$self->{$cache_accessor}->$method(@_);
	    };

	    *{$alias} = $subref;
	}
    }
}

1;
