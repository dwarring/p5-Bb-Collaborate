package Elive::Entity::ParticipantList;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{Elive::Entity};

use Elive::Entity::Participant;
use Elive::Util;
use Elive::Array;

__PACKAGE__->entity_name('ParticipantList');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

has 'participants' => (is => 'rw', isa => 'ArrayRef[Elive::Entity::Participant]|Elive::Array',
    coerce => 1);

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'ArrayRef[HashRef]'
          => via {
	      my $a = [ map {Elive::Entity::Participant->new($_)} @$_ ];
	      bless ($a, 'Elive::Array');
	      $a;
};

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'Str'
          => via {
	      my $spec;
	      my @participants = map {
		  m{^ \s* ([0-9]+) \s* (= ([0-3]) \s*)? $}x
		  or die "'$_' not in format: userId=role";

		  my $userId = $1;
		  my $roleId = $3;
		  $roleId = 3 unless defined $roleId;

		  {user => {userId => $userId},
		   role => {roleId => $roleId}};
	      } split(';');

	      my $a = [ map {Elive::Entity::Participant->new($_)} @participants ];
	      bless ($a,'Elive::Array');
	      $a;
          };

=head1 NAME

Elive::Entity::ParticipantList - Meeting Participants entity class

=head1 DESCRIPTION

This is the entity class for meeting participants.

The participants property is an array of Elive::Entity::Participant.

=cut

=head1 METHODS

=cut

=head2 insert

Note that for inserts, you only need to include the userId in the
user records.  The following will be sufficient to associate two
participants with a meeting.

    my $participant_list = Elive::Entity::ParticipantList->insert(
    {
	meetingId => 123456,
	participants => "111111=2;222222=3"
    },
    );

=cut


=head2 construct

Construct a participant list from data.


Common usage is:

    my $participant_list = Elive::Entity::ParticipantList->construct(
        {meetingId => 123456, participants => '11111111=3;222222=2'}
     );

If you prefer, you can construct the participant list from a reference:

    my $participant_list = Elive::Entity::ParticipantList->construct(
    {
	meetingId => 123456,
	participants => [
	    {
		user => {userId => 11111111}, #user id
		role => {roleId => 3},
	    },
	    {
		user => {userId => 22222222}, #user id
		role => {roleId => 2},
	    },
	],
    },
    );

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
    return $class->SUPER::retrieve_all($vals,
				       adapter => 'listParticipants',
				       %opt);
}

sub _freeze {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my $frozen = $class->SUPER::_freeze($data, %opt);

    if (my $participants = delete $frozen->{participants}) {
	#
	# NOTE: thawed data is returned as the 'participants' property.
	# but for frozen data the parmeter name is 'users'. Also
	# setter methods expect a stringified digest in the form
	#  userid=roleid[;userid=roleid]
	#
	#
	# allow prefrozen
	#
	my $reftype = Elive::Util::_reftype($participants);

	my $users_frozen;

	if ($reftype) {
	    die "expected participants to be an ARRAY, found $reftype"
		unless ($reftype eq 'ARRAY');

	    my @users = map {
		Elive::Entity::Participant->stringify($_);
	      } @$participants;

	    $users_frozen = join(';', @users);
	}
	else {
	    $users_frozen = $participants;
	}

	$frozen->{users} = $users_frozen;
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

sub _insert_class {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    $class->SUPER::_insert_class($data,
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
    # Ok, we need to handle our own readback.
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
