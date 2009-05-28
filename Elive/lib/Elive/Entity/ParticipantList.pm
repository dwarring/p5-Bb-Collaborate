package Elive::Entity::ParticipantList;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{Elive::Entity};

use Elive::Entity::Meeting;
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

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'ArrayRef[Str]'
          => via {
	      my @participants = map {
		  _parse_participant($_)
	      } @$_;

	      my $a = [ map {Elive::Entity::Participant->new($_)} @participants ];
	      bless ($a, 'Elive::Array');
	      $a;
};

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'Str'
          => via {
	      my @participants = map {
		  _parse_participant($_)
	      } split(';');

	      my $a = [ map {Elive::Entity::Participant->new($_)} @participants ];
	      bless ($a,'Elive::Array');
	      $a;
          };

=head1 NAME

Elive::Entity::ParticipantList - Meeting Participants entity class

=head1 DESCRIPTION

This is the entity class for meeting participants.

The participants property is an array of type Elive::Entity::Participant.

=cut

=head1 METHODS

=cut

sub _retrieve_all {
    my $class = shift;
    my $vals = shift;
    my %opt = @_;

    #
    # No getXxxx adapter use listXxxx
    #
    return $class->SUPER::_retrieve_all($vals,
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
	my $reftype = Elive::Util::_reftype($participants);

	if ($reftype) {
	    die "expected participants to be an ARRAY, found $reftype"
		unless ($reftype eq 'ARRAY');
	}
	else {
	    #
	    # participant list passed as a string.
	    #
	    $_ = [split(';')] for ($participants);
	}

	my @users = map {
	    my $p = ref $_
		? $_
		: _parse_participant($_);

	    Elive::Entity::Participant->stringify($p);
	} @$participants;
	
	$frozen->{users} = join(';', @users);
    }

    return $frozen;
}

sub _parse_participant {
    local ($_) = shift;

    m{^ \s* (.*?) \s* (= ([0-3]) \s*)? $}x
	or die "'$_' not in format: userId=role";

    my $userId = $1;
    my $roleId = $3;
    $roleId = 3 unless defined $roleId;

    return {user => {userId => $userId},
	    role => {roleId => $roleId}};
}

=head2 insert

Note that for inserts, you only need to include the userId in the
user records.  The following will be sufficient to associate two
participants with a meeting.

Participants are specified in the format: userId[=roleId], where
the role is 3 for a normal participant or 2 or higher to grant the
user moderator privileges for the meeting.

The list of participants may be specified as a ';' separated string:

    my $participant_list = Elive::Entity::ParticipantList->insert(
    {
	meetingId => 123456,
	participants => "111111=2;222222"
    },
    );

The participants may also be specified as an array ref:

    my $participant_list = Elive::Entity::ParticipantList->insert(
    {
	meetingId => 123456,
	participants => ['111111=2', 222222]
    },
    );

Note that if you empty the participant list, C<reset> will be called.

=cut

sub insert {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    my $participants = $data->{participants};

    #
    # have a peak at the participantList, if it's empty,
    # we need to call the clearParticipantList adapter.
    #

    if ((!defined $participants)
	|| (Elive::Util::_reftype($participants) eq 'ARRAY' && !@$participants)
	|| $participants eq '') {

	goto sub {$class->reset(%opt)};
    }

    my $adapter = $class->check_adapter('setParticipantList');

    $class->SUPER::insert($data,
			  adapter => $adapter,
			  %opt);
}

=head2 update

    my late_comer = Elive::Entity::Participant->retrieve([$user_id]);
    my $meeting_id = 111111111;
    my $participant_list = Elive::Entity::User->retrieve([$meeting_id]);

    $participant_list->particpants->add($late_comer);
    $participant_list->update;

Update meeting participants.

Note that if you empty the participant list, C<reset> will be called.

=cut

sub update {
    my $self = shift;
    my $data = shift;
    my %opt = @_;

    my $participants = $data->{participants};
    $participants = $self->participants
	unless defined $participants;

    if ((!defined $participants)
	|| (Elive::Util::_reftype($participants) eq 'ARRAY' && !@$participants)
	|| $participants eq '') {

	#
	# treat an empty list as an implied reset. The 'setParticipantList'
        # adapter will barf otherwise.
	#
	goto sub {$self->reset(%opt)};
    }

    my $adapter = $opt{adapter} || $self->check_adapter('setParticipantList');

    $self->SUPER::update($data,
			  adapter => $adapter,
			  %opt);
}


=head2 reset 

    $participant_list->reset

Reset the participant list. This will set the meeting facilitator as
the only participant, with a role of 2 (moderator).

=cut

sub reset {
    my $self = shift;
    my %opt = @_;

    my $meeting_id = $self->meetingId
	or die "unable to get meetingId";

    my $meeting = Elive::Entity::Meeting->retrieve([$meeting_id],
						   reuse => 1)
	or die "meeting not found: ".$meeting_id;

    my $facilitator_id = $meeting->facilitatorId
	or die "no facilitator found for meeting: $meeting_id";

    #
    # Expect the list to be set to just include the meeting facilitator
    # as a moderator (role = 2). Set it now, and confirm this in the
    # readback.
    #
    my %updates
	= (participants => [{user => $facilitator_id, role => 2}]);

    $self->SUPER::update(\%updates,
			 adapter => 'resetParticipantList',
			 %opt,
	);
}

sub _readback {
    my $class = shift;
    my $som = shift;
    my $updates = shift;
    my $connection = shift;

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

    my $self = $class->retrieve([$meeting_id], connection => $connection)
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
