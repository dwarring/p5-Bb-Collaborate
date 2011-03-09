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
use Carp;

__PACKAGE__->entity_name('Session');
__PACKAGE__->collection_name('Sessions');
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');
__PACKAGE__->_alias(meetingId => 'id');
__PACKAGE__->_alias(sessionId => 'id');

our %handled = (meetingId => 1);

our %delegates = (
    meeting => 'Elive::Entity::Meeting',
    meeting_parameters => 'Elive::Entity::MeetingParameters',
    server_parameters => 'Elive::Entity::ServerParameters',
    participant_list => 'Elive::Entity::ParticipantList',
    );

foreach my $prop (sort keys %delegates) {
    my $class = $delegates{$prop};
    my @delegates = grep {!$handled{$_}++} ($class->properties, $class->derivable);
    push (@delegates, qw{buildJNLP add_preload remove_preload is_participanr us_moderator list_preloads list_recordings})
	if $prop eq 'meeting';

    has $prop
    => (is => 'rw', isa => $class, coerce => 1,
	handles => \@delegates,
	lazy => 1,
	default => sub {$class->retrieve($_[0]->id, copy => 1, connection => $_[0]->connection)},
    );
}
    
=head1 NAME

Elive::View::Session - Session view class

=head1 DESCRIPTION

A session is a composite view of meetings, meeting participants, server
parameters and participants.

=cut

sub _owned_by {
    my $class = shift;
    my $delegate_class = shift;
    my @props = @_;

    my $delegate_types = $delegate_class->property_types;
    my $delegate_aliases = $delegate_class->_aliases;

    return grep {exists $delegate_types->{$_}
		 or exists $delegate_aliases->{$_}} @props
}

sub set {
    my $self = shift;
    my %data = @_;

    foreach my $delegate (sort keys %delegates) {

	my $delegate_class = $delegates{$delegate};
	my @delegate_props = $self->_owned_by($delegate_class => sort keys %data);
	my %delegate_data =  map {$_ => delete $data{$_}} @delegate_props;

	$delegate_class->set( %delegate_data );
    }

    carp 'unknown session attributes '.join(' ', sort keys %data).'. expected: '.join(' ', sort $self->properties)
	if keys %data;

    return $self;
}

sub insert {
    my $class = shift;
    my %data = %{ shift() };
    my %opts = @_;

    #
    # start by inserting the meeting
    #
    my @meeting_props = $class->_owned_by('Elive::Entity::Meeting' => (sort keys %data));

    my %meeting_data = map {
	$_ => delete $data{$_}
    } @meeting_props;

    my $meeting = Elive::Entity::Meeting->insert(\%meeting_data, %opts);

    my $self = bless {id => $meeting->meetingId,
		      meeting => $meeting}, $class;

    $self->connection( $meeting->connection );
    #
    # from here on in, it's just a matter of updating attributes owned by
    # the other entities
    #
    $self->update(\%data, %opts)
	if keys %data;

    return $self;
}

sub update {
    my $self = shift;
    my %data = %{ shift() };
    my %opts = @_;

   foreach my $delegate (sort keys %delegates) {

	my $delegate_class = $delegates{$delegate};
	my @delegate_props = $self->_owned_by($delegate_class => sort keys %data);
	next unless @delegate_props
	    || ($self->{$delegate} && $self->{$delegate}->is_changed);

	my %delegate_data = map {$_ => delete $data{$_}} @delegate_props;

	$self->$delegate->update( \%delegate_data, %opts );
    }

    return $self;
}

sub delete {
    my $self = shift;
    my %opt = @_;

    $self->meeting->delete;
    foreach my $delegate (sort keys %delegates) {
	$self->$delegate->_deleted(1) if $self->{$delegate};
    }

    return 1;
}

sub properties {
    my $class = shift;

    my %seen = (meetingId => 1);

    my @all_properties = grep {! $seen{$_}++} (
	'id',
	map {$_->properties} sort values %delegates,
    );

    return @all_properties;
}

sub property_types {
    my $class = shift;

    my $id = $class->SUPER::property_types->{id};

    my %property_types = (
	id => $id,
	map { %{$_->property_types} } sort values %delegates,
    );

    delete $property_types{meetingId};

    return \%property_types;
}

sub derivable {
    my $class = shift;
    return (
	map { $_->derivable } sort values %delegates,
	);
}

sub retrieve {
    my $class = shift;
    my $id = shift;
    my %opt = @_;
    ($id) = @$id if ref($id);
    my $self = bless {id => $id}, $class;

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

	my $self = bless {id => $meeting->meetingId}, $class;
	$self->meeting($meeting);
	$self->connection($connection);

	$self;
    } @$meetings;

    return \@sessions;
}

=head2 RESTRICTIONS

A list C<list> method is provied for completness. However, the C<list> method
performs secondary fetches on each record and is fairly slow. Also note that
it only allows filtering on meeting properties.

=head2 SEE ALSO

L<Elive::Entity::Meeting>
L<Elive::Entity::MeetingParameters>
L<Elive::Entity::ServerParameters>
L<Elive::Entity::ParticipantList>

=cut

1;
