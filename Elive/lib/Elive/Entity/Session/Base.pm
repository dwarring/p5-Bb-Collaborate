package Elive::Entity::Session::Base;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Entity::Meeting;
use Elive::Entity::ServerParameters;
use Elive::Entity::MeetingParameters;
use Elive::Entity::ParticipantList;

has 'meeting' => (is => 'rw', isa => 'Elive::Entity::Meeting');
has 'server_parameters' => (is => 'rw', isa => 'Elive::Entity::ServerParameters');
has 'meeting_parameters' => (is => 'rw', isa => 'Elive::Entity::MeetingParameters');
has 'participants' => (is => 'rw', isa => 'Elive::Entity::ParticipantList');

=head1 NAME

Elive::Entity::Session::Base - Base class for Elive::Entity::Session

=head1 DESCRIPTION

This is a base class inherited by L<Elive::Entity::Session>. You probably wont
need to use it directly.

The C<createSession> and C<updateSession> commands accept a flat list of
paramaters, but include the individual meeting parameters, server parameters
and participants that comprise the session.

This class declares these constitutants. It is particularly concerned with
the processing of responses.

=cut

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

1;
