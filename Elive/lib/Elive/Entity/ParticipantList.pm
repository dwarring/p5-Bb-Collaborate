package Elive::Entity::ParticipantList;
use warnings; use strict;

use base qw{ Elive::Entity };
use Moose;

use Elive::Entity::Participant;
use Elive::Util;

__PACKAGE__->entity_name('ParticipantList');

has 'meetingId' => (is => 'rw', isa => 'Pkey', required => 1);
has 'participants' => (is => 'rw', isa => 'ArrayRef[Elive::Entity::Participant]');

=head1 NAME

Elive::Entity::ParticipantList - Meeting Participants entity class

=head1 DESCRIPTION

This is the entity class for meeting participants.

The participants property is an array of Elive::Entity::Participant.

=cut

=head2 retrieve_all

Retrieve the participant list for this meeting.

my $participant_list
    = Elive::Entity::Participant
        ->retrieve_all([$meeting_id])->[0];

=cut

sub retrieve_all {
    my $class = shift;
    my $vals = shift;
    my %opt = @_;

    #
    # No getXxxx adapter use listXxxx
    #
    return $class->SUPER::retrieve_all($vals, %opt,
				      adapter => 'listParticipants');
}

sub _freeze {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my $frozen = $class->SUPER::_freeze($data, %opt);

    if ((my $participants = delete $frozen->{participants})
	&& $opt{mode} =~ m{insert|update}i) {
	#
	# We're using resetParticipantList, both for inserts and
	# updates. This takes a stringified list of users as 'users'.
	# The fetch mode returns the final list of 'particpiants'
	#

	die "expected participants to be an ARRAY"
	    unless (Elive::Util::_reftype($participants) eq 'ARRAY');

	my @users = map {
	    my $str = UNIVERSAL::can($_,'_stringify_self')
		? $_->_stringify_self
		: $_;
	} @$participants;


	$frozen->{users} = join(';', @users);
    }

    return $frozen;
}

=head2 insert

    my $user1 = Elive::Entity::User->retrieve($user1_id);
    my $user2 = Elive::Entity::User->retrieve($user2_id);

    my $partcipants = Elive::Entity::participantList->insert({
	      meetingId => 123456,
	      particpants => [
                  {user => $user1, role => 3},
                  {user => $user2, role => 3},
              ],
              }
	    )};

Insert meeting participants

=cut

sub insert {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my $result;

    my $meeting_id = $data->{meetingId};
    my $participant_list;

    my $data_image = Elive::Entity::ParticipantList->construct(
	Elive::Util::_clone($data, copy => 1),
	);
 
    my $expected_participants = $data_image->participants->_stringify_self;
    $data_image = undef;

    eval {
	$participant_list = $class->SUPER::insert(
	    $data,
	    adapter => 'setParticipantList',
	    %opt );
    };

    if (my $err = @_) {
	return $class->__handle_response($err, $meeting_id,
					 $expected_participants);
    }

    return $participant_list;
}

=head2 update

    my late_comer = Elive::Entity::Participant->retrieve($user_id);
    my $meeting_id = 111111111;
    my $participant_list = Elive::Entity::User->retrieve($meeting_id);

    $participant_list->particpants->add($late_comer);
    $participant_list->update;

Update meeting participants

=cut

sub update {
    my $self = shift;
    my $data = shift;
    my %opt = @_;

    my $meeting_id = $self->meetingId;
    my $expected_participants = $self->participants->_stringify_self;
    my $participant_list;

    eval {
	$participant_list
	    = $self->SUPER::update($data,
				   adapter => 'setParticipantList',
				   %opt );

    };

    if (my $err = @_) {
	return ref($self)->__handle_response($err, $meeting_id,
	    $expected_participants);
    }

    return $participant_list;
}

sub __handle_response {
    my $class = shift;
    my $err = shift;
    my $meeting_id = shift;
    my $expected_participants;
    #
    # sometimes get back an empty response from setPartipcantList
    # if this happens abort the standard readback and reimplement
    # our by re-retrieving the record and comparing against the
    # the saved values.
    # 
    if ($meeting_id && $err =~ m{unexpected soap response}i) {
	warn "warning: $err";
	my $self = $class->retrieve([$meeting_id]);

	die "unable to retrieve $class/$meeting_id"
	    unless $self;

	my $actual_participants = $self->participants->_stringify_self;
	die "readback failed on participants:\nexpected $expected_participants\nactual: $actual_participants"
	    unless $expected_participants eq $actual_participants;

    }
    else {
	die $err;
    }
}

1;
