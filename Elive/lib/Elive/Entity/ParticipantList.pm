package Elive::Entity::ParticipantList;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{Elive::Entity};

use Elive::Entity::Participant;
use Elive::Util;

__PACKAGE__->entity_name('ParticipantList');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

has 'participants' => (is => 'rw', isa => 'ArrayRef[Elive::Entity::Participant]',
    coerce => 1);
coerce 'ArrayRef[Elive::Entity::Participant]' => from 'ArrayRef[HashRef]'
          => via {[ map {Elive::Entity::Participant->new($_) } @$_ ]};

=head1 NAME

Elive::Entity::ParticipantList - Meeting Participants entity class

=head1 DESCRIPTION

This is the entity class for meeting participants.

The participants property is an array of Elive::Entity::Participant.

=cut

=head1 METHODS

=cut

=head2 construct

    my $participant_list = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 123456,
	participants => [
	    {
		user => 11111111, #user id
		role => 2,
	    },
	    {
		user => 22222222, #user id
		role => 2,
	    },
	],
    },
    );

Construct a participant list from data.

=cut

sub construct {
    my $self = shift->SUPER::construct(@_);
    bless $self->participants, 'Elive::Array';
    $self;
}


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
	    my $str = UNIVERSAL::can($_,'stringify')
		? $_->stringify
		: $_;
	} @$participants;


	$frozen->{users} = join(';', @users);
    }

    return $frozen;
}

=head2 insert

    my $partcipants = Elive::Entity::participantList->insert({
	      meetingId => 123456,
	      particpants => [
                  {user => $userId_1, role => 3},
                  {user => $userId_2, role => 3},
              ],
              }
	    )};

Insert meeting participants

=cut

sub insert {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    $class->SUPER::insert($data,
			  adapter => 'setParticipantList',
			  %opt);
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
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    $class->SUPER::update($data,
			  adapter => 'setParticipantList',
			  %opt);
}

sub _readback {
    my $class = shift;
    my $som = shift;
    my $updates = shift;

    #
    # sometimes get back an empty response from setParticantList
    # if this happens we'll have to handle it ourselves.
    #
    my $result = $som->result;
    return $class->SUPER::_readback($som, $updates, @_)
	if Elive::Util::_reftype($result);
    #
    # Ok, we need to handle our own readbaOAck.
    #
    $class->_check_for_errors($som);

    my $meeting_id = $updates->{meetingId}
    || die "couldn't find meetingId";

    my $self = $class->retrieve([$meeting_id])
	or die "unable to retrieve $class/$meeting_id";

    my $rows = [$self];

    $class->SUPER::_readback_check($updates, $rows, @_);
}

=head2 list

The list method is not available for participant lists. You'll need
to retrieve on a meeting id.

=cut

sub list {shift->_not_available}

1;
