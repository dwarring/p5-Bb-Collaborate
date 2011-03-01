package Elive::Entity::ParticipantList;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Entity::ParticipantList::Participant;
use Elive::Entity::ParticipantList::Participants;
use Elive::Entity::User;
use Elive::Entity::Group;
use Elive::Entity::Role;
use Elive::Entity::Meeting;
use Elive::Entity::InvitedGuest;
use Elive::Util;

use Carp;

__PACKAGE__->entity_name('ParticipantList');

has 'meetingId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('meetingId');
__PACKAGE__->params(users => 'Str');

has 'participants' => (is => 'rw', isa => 'Elive::Entity::ParticipantList::Participants',
    coerce => 1);
#
# NOTE: thawed data may be returned as the 'participants' property.
# but for frozen data the parameter name is 'users'.
#
__PACKAGE__->_alias(users => 'participants', freeze => 1);

=head1 NAME

Elive::Entity::ParticipantList - Meeting Participants entity class

=head1 DESCRIPTION

This is the entity class for meeting participants.

The participants property is an array of type Elive::Entity::Participant.

=head2 User Participants

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

=head2 Groups of Participants

Groups of users may also be assigned to a meeting. All users that are member of
that group are then able to participate in the meeting, and are assigned the
given role.

By convention, a leading '*' indicates a group:

    #
    # Set alice and bob as moderators. Then add all students in the
    # cookery class:
    #
    $participant_list->participants('alice=2;bob=2;*cookery_class=3');
    $participant_list->update;

Similar to the above:

    $participant_list->participants(['alice=2', 'bob=2', '*cookery_class=3']);
    $participant_list->update;

As a list of hashrefs:

    $participant_list->participants([
              {user => 'alice', role => 2},
              {user => 'bob', role => 2},
              {group => 'cookery_class', role => 3},
    ]);
    $participant_list->update;

=head2 Command Selection

By default this command uses the C<setParticipantList> SOAP command, which
doesn't handle groups. If any groups are specified, it will switch to using
C<updateSession>, which does handle groups.

=cut

=head1 METHODS

=cut

sub _retrieve_all {
    my ($class, $vals, %opt) = @_;

    #
    # No getXxxx command use listXxxx
    #
    return $class->SUPER::_retrieve_all($vals,
				       command => 'listParticipants',
				       %opt);
}

=head2 update

This method updates meeting participants.

    my $participant_list
         = Elive::Entity::ParticipantList->retrieve([$meeting_id]);
    $participant_list->participants->add($alice->userId, $bob->userId);
    $participant_list->update;

Note:

=over 4

=item if you specify an empty list, C<reset> method will be called. The
resultant list wont be empty, but will have the moderator as the sole
participant.

=back

=cut

sub update {
    my ($self, $update_data, %opt) = @_;

    if (defined $update_data) {

	die 'usage: $obj->update( \%data, %opt )'
	    unless (Elive::Util::_reftype($update_data) eq 'HASH');

	$self->set( %$update_data )
	    if (keys %$update_data);
    }

    my $meeting_id = $self->meetingId
	or die "unable to get meetingId";

    my $meeting = Elive::Entity::Meeting
	->retrieve([$meeting_id],
		   reuse => 1,
		   connection => $self->connection,
	) or die "meeting not found: ".$meeting_id;

    my ($users, $groups, $guests) = $self->_collate_participants;
    # support for guests - tba

    #
    # make sure that the facilitator is included with a moderator role
    #
    $users->{ $meeting->facilitatorId } = 2;

    my $participants = $self->_set_participant_list( $users, $groups, $guests );
    #
    # do our readback
    #
    $self->revert;
    my $class = ref($self);
    $self = $class->retrieve([$self->id], connection => $self->connection);

    my ($added_users, $_added_groups) = $self->_collate_participants;
    #
    # a common scenario is adding unknown users. Check for this specific
    # condition and raise a specific friendlier error.
    #
    my %requested_users = %$users;
    my $requested_user_count = scalar keys %requested_users;
    delete @requested_users{ keys %$added_users };
    my @rejected_users = sort keys %requested_users;
    my $rejected_user_count = scalar @rejected_users;

    Carp::croak "unable to add $rejected_user_count of $requested_user_count participants; rejected users: @rejected_users"
	if $rejected_user_count;

    $class->_readback_check({meetingId => $self->meetingId,
			     participants => $participants},
			    [$self]);

    return $self;
}

sub _collate_participants {
    my $self = shift;

    my @raw_participants = @{ $self->participants || [] };

    my %users;
    my %groups;
    my %guests;

    foreach (@raw_participants) {
	my $participant = Elive::Entity::ParticipantList::Participant->_parse($_);
	my $id;
	my $roleId = Elive::Entity::Role->stringify( $participant->{role} )
	    || 3;

	if (! $participant->{type} ) {
	    $id = Elive::Entity::User->stringify( $participant->{user} );
	    $users{ $id } = $roleId;
	}
	elsif ($participant->{type} == 1) {
	    $id = Elive::Entity::Group->stringify( $participant->{group} );
	    $groups{ $id } = $roleId;
	}
	elsif ($participant->{type} == 2) {
	    $id = Elive::Entity::InvitedGuest->stringify( $participant->{guest} );
	    $guests{ $id } = $roleId;
	}
	else {
	    carp("unknown type: $participant->{type} in participant list: ".$self->id);
	}
    }

    return (\%users, \%groups, \%guests);
}

sub _set_participant_list {
    my $self = shift;
    my $users = shift;
    my $groups = shift;
    my $guests = shift;

    my $som;

    my @participants;

    foreach (keys %$users) {
	push(@participants, Elive::Entity::ParticipantList::Participant->new({user => $_, role => $users->{$_}, type => 0}) )
    }

    foreach (keys %$groups) {
	push(@participants, Elive::Entity::ParticipantList::Participant->new({group => $_, role => $groups->{$_}, type => 1}) )
    }

    foreach (keys %$guests) {
	push(@participants, Elive::Entity::ParticipantList::Participant->new({guest => $_, role => $guests->{$_}, type => 2}) )
    }

    if (keys %$groups || keys %$guests) {
	#
	# switch to using the 'updateSession' command, which can handle groups
	# and invited guests.
	#
	# We need to refetch and resupply meeting details.
	#
	my $meeting = Elive::Entity::Meeting->retrieve( $self, reuse => 1, connection => $self->connection );

	my @invited_moderators;
	my @invited_participants;
	my @invited_guests;

	foreach (@participants) {
	    if ($_->{guest}) { #guest
		push (@invited_guests, Elive::Entity::InvitedGuest->stringify($_->{guest}))
	    }
	    else {
		my $role = $_->{role};
		my $spec = ($_->{group}
			    ? '*' .Elive::Entity::Group->stringify($_->{group})
			    : Elive::Entity::User->stringify($_->{user})
			    );
		if ($role >= 3) {
		    push (@invited_participants, $spec)
		}
		else {
		    push (@invited_moderators, $spec)
		}
	    }
	}

	my %session_params = (
	    id => $meeting,
	    invitedParticipantsList => \@invited_participants,
	    invitedModerators => \@invited_moderators,
	    invitedGuests => \@invited_guests,
	    );


	$som = $meeting->update_session(%session_params);

    }
    else {
	my %params;
	$params{meetingId} = $self;
	$params{participants} = \@participants;
	$som = $self->connection->call('setParticipantList' => %{$self->_freeze(\%params)});
	$self->connection->_check_for_errors( $som );
    }


    return \@participants;
}

=head2 reset 

    $participant_list->reset

Reset the participant list. This will set the meeting facilitator as
the only participant, with a role of 2 (moderator).

=cut

sub reset {
    my ($self, %opt) = @_;
    return $self->update({participants => []}, %opt);
}

=head2 insert
 
    my $participant_list = Elive::Entity::ParticipantList->insert({
       meetingId => $meeting_id,
       participants => '111111=2;33333'
       });

Note that if you empty the participant list, C<reset> will be called.

=cut

sub insert {
    my ($class, $data, %opt) = @_;

    my $meeting_id = delete $data->{meetingId}
    or die "can't insert participant list without meetingId";
    my $self = $class->retrieve([$meeting_id], reuse => 1);

    $self->update($data, %opt);

    return $self;
}

=head2 list

The list method is not available for participant lists. You'll need
to retrieve on a meeting id.

=cut

sub list {return shift->_not_available}

=head1 SEE ALSO

=over 4

=item Elive::Entity::Meeting

=item Elive::Entity::ParticipantList::Participants

=item Elive::Entity::ParticipantList::Participant

=back

=cut

sub _thaw {
    my ($class, $db_data, @args) = @_;

    $db_data = Elive::Util::_clone( $db_data );  # take a copy
    #
    # the soap record has a Participant property that can either
    # be of type user or group. However, Elive has separate 'user'
    # and 'group' properties. Resolve here.
    #
    if ($db_data->{ParticipantListAdapter}) {
	if (my $participants = $db_data->{ParticipantListAdapter}{Participants}) {
	    $participants = [$participants]
		unless Elive::Util::_reftype($participants) eq 'ARRAY';

	    foreach (@$participants) {
		my $p = $_->{ParticipantAdapter};
		if ($p && $p->{Participant}) {
		    #
		    # peek at the the type property. 0 => user, 1 => group
		    # a group record, rename to Group, otherwise treat
		    #
		    if (! $p->{Type}) {
			$p->{User} = delete $p->{Participant}
		    }
		    elsif ($p->{Type} == 1) {
			$p->{Group} = delete $p->{Participant}
		    }
		    elsif ($p->{Type} == 2) {
			$p->{Guest} = delete $p->{Participant}
		    }
		}
	    }
	}
    }

    return $class->SUPER::_thaw($db_data, @args);
}

1;
