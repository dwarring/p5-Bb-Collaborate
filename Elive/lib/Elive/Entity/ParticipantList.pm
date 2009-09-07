package Elive::Entity::ParticipantList;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{Elive::Entity};

use Elive::Entity::Meeting;
use Elive::Entity::Participant;
use Elive::Util;
use Elive::Array::Participants;

use Scalar::Util;

__PACKAGE__->entity_name('ParticipantList');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');

has 'participants' => (is => 'rw', isa => 'ArrayRef[Elive::Entity::Participant]|Elive::Array::Participants',
    coerce => 1);
# NOTE: thawed data may be returned as the 'participants' property.
# but for frozen data the parameter name is 'users'. Also

__PACKAGE__->_alias(users => 'participants', freeze => 1);

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'ArrayRef[HashRef]'
          => via {
	      my $a = [ map {Elive::Entity::Participant->new($_)} @$_ ];
	      bless ($a, 'Elive::Array::Participants');
	      $a;
};

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'ArrayRef[Str]'
          => via {
	      my @participants = map {Elive::Entity::Participant->_parse($_)} @$_;
	      my $a = [ map {Elive::Entity::Participant->new($_)} @participants];
	      bless ($a, 'Elive::Array::Participants');
	      $a;
};

coerce 'ArrayRef[Elive::Entity::Participant]' => from 'Str'
          => via {
	      my @participants = map {Elive::Entity::Participant->_parse($_)} split(';');

	      my $a = [ map {Elive::Entity::Participant->new($_)} @participants ];
	      bless ($a,'Elive::Array::Participants');
	      $a;
          };

=head1 NAME

Elive::Entity::ParticipantList - Meeting Participants entity class

=head1 DESCRIPTION

This is the entity class for meeting participants.

The participants property is an array of type Elive::Entity::Participant.

=head2 Participants

The I<participants> property may be specified in the format: userId[=roleId],
where the role is 3 for a normal participant or 2 for a meeting moderator.

Participants may be specified as a ';' separated string:

    my $participant_list = $meeting->participant_list;

    $participant_list->participants('111111=2;222222');
    $participant_list->update;

Participants may also be specified as an array of scalars:

    $participant_list->participants(['111111=2', 222222]);
    $participant_list->update;

Or an array of hashrefs:

    $participant_list->participants([{user => 111111, role =>2},
                                     {user => 222222}]);
    $participant_list->update;

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

    if (my $users = $frozen->{users}) {
	#
	# Need to flatten our users struct.
	#
	# Setter methods expect a stringified digest in the form:
	# userid=roleid[;userid=roleid]
	#
	my $reftype = Elive::Util::_reftype($users);

	if ($reftype) {
	    die "expected users to be an ARRAY, found $reftype"
		unless ($reftype eq 'ARRAY');
	}
	else {
	    #
	    # participant list passed as a string.
	    #
	    $_ = [split(';')] for ($users);
	}

	my @users_stringified = map {
	    my $p = ref $_
		? $_
		: Elive::Entity::Participant->_parse($_);

	    Elive::Entity::Participant->stringify($p);
	} @$users;
	
	$frozen->{users} = join(';', @users_stringified);
    }

    return $frozen;
}

=head2 update

    my $participant_list
         = Elive::Entity::ParticipantList->retrieve([$meeting_id]);
    $participant_list->add('4444444');
    $participant_list->update;

Update meeting participants.

Note that if you empty the participant list, C<reset> will be called.

=cut

sub update {
    my $self = shift;
    my $update_data = shift;
    my %opt = @_;

    if ($update_data) {

	die 'usage: $obj->update( \%data )'
	    unless (Elive::Util::_reftype($update_data) eq 'HASH');

	$self->set( %$update_data)
	    if (keys %$update_data);
    }

    my $participants = $self->participants;

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

    if ($self->is_changed) {
	$self->SUPER::update(undef,
			     adapter => $adapter,
			     %opt);
    }
    elsif ($self->_is_lazy) {
	#
	# input participants list may have been lazily populated. 
	# Reread from database to fully stantiate objects.
	#
	my $class = ref($self);
	$class->retrieve([$self->id]);
	$self;
    }
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

    $self->update(\%updates,
		  adapter => 'resetParticipantList',
		  %opt,
	);
}

#
# &_is_lazy
# require a round trip to stantiate objects and users and roles
# from elm.
#

sub _is_lazy {
    my $self = shift;

    my @changed = $self->SUPER::is_changed(@_);
    unless (@changed) {

	my $participants = $self->participants;
	@changed = ('participants')
	    if ($participants
		&& grep {!(Scalar::Util::blessed($_)
			   && Scalar::Util::blessed($_->{user})
			   && Scalar::Util::blessed($_->{role}))} @$participants);
    }

    return @changed;
}

sub _readback {
    my $class = shift;
    my $som = shift;
    my $updates = shift;
    my $connection = shift;

    #
    # sometimes get back an empty response from setParticipantList,
    # however, the data hash being saved. Seems to be a problem in
    # elm circa 9.0.
    #
    # If this happens, retrieve the data that we just saved and
    # complete the readback check.
    #
    my $result = $som->result;
    return $class->SUPER::_readback($som, $updates, @_)
	if Elive::Util::_reftype($result);
    #
    # Ok, we need to handle our own error checking and readback.
    #
    $class->_check_for_errors($som);

    my $meeting_id = $updates->{meetingId}
    || die "couldn't find meetingId";

    my $row = $class->retrieve([$meeting_id],
			       connection => $connection,
			       raw => 1,
	)
	or die "unable to retrieve $class/$meeting_id";

    $class->SUPER::_readback_check($updates, [$row], @_);
}

=head2 insert

The insert method is not for participants lists. This entity is created
automatically, when meetings are created.

=cut

sub insert {shift->_not_available}

=head2 list

The list method is not available for participant lists. You'll need
to retrieve on a meeting id.

=cut

sub list {shift->_not_available}

=head1 SEE ALSO

=over 4

=item Elive::Entity::Meeting

=item Elive::Entity::Participant

=item 

=cut

1;
