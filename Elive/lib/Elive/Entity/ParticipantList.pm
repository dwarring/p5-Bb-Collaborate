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

    my $user2_obj = Elive::Entity::User->retrieve($user2_id);

    my $participant_list = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 123456,
	participants => [
	    {
		user => {userId => 11111111,
			 loginName => 'test_user',
		},
		role => {roleId => 2},
	    },
            $user2_obj,
	    
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
 
    my $expected_participants = $data_image->participants->stringify;
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

sub _readback_check {
    my $class = shift;
    my $updates = shift;
    my $rows = shift;

    #
    # sometimes get back an empty response from setParticantList
    # if this happens Re-retreive the updates, then complete the readback.
    #
    unless (Elive::Util::_reftype($rows) eq 'ARRAY'
	    && @$rows
	    && (my $meeting_id = $updates->{meetingId})
	) {

	my $self = $class->retrieve([$meeting_id]);

	die "unable to retrieve $class/$meeting_id"
	    unless $self;

	$rows = [$self];
    }

    $class->SUPER::_readback_check($updates, $rows, @_);
}

=head2 list

The list method is not available for participant lists. You'll need
to retrieve on a meeting id.

=cut

sub list {shift->_not_available}

1;
