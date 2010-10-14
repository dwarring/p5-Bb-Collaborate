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
use Elive::Util;

use Scalar::Util;

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

Groups are applicable under LDAP. If you add groups to the participant list,
then all members of the group may join the meeting, and are assigned the
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
    $participant_list->participants->add('alice', 'bob');
    $participant_list->update;

Note:

=over 4

=item if you specify an empty list, C<reset> method will be called. The
resultant list wont be empty, but will have the moderator as the sole
participant.

=item the c<setParticipantList> SOAP command can overflow if there are 100s of
participants, so the C<addParticipant> is used instead. If there are more 300
participants, they are batched an inserted in lots of 250.

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
	)
	or die "meeting not found: ".$meeting_id;


    my @raw_participants = @{ $self->participants || [] };

    #
    # Weed out duplicates and make sure that the facilator is included
    #
    my %users;
    my %groups;

    foreach (@raw_participants) {
	my $participant = Elive::Entity::ParticipantList::Participant->_parse($_);
	my $id;
	my $roleId = Elive::Entity::Role->stringify( $participant->{role} )
	    || 3;

	if ($participant->{type}) {
	    $id = Elive::Entity::Group->stringify( $participant->{group} );
	    $groups{ $id } = $roleId;
	}
	else {
	    $id = Elive::Entity::User->stringify( $participant->{user} );
	    $users{ $id } = $roleId;
	}
    }

    #
    # make sure that the facilitator is included with a moderator role
    #
    $users{ $meeting->facilitatorId } = 2;

    foreach my $group_id (keys %groups) {
	#
	# Current restriction with passing groups via setParticipantList
	# etc adapters.
	#
	carp "client side expansion of group: $group_id";
	my $role = $groups{ $group_id };
	my $group = Elive::Entity::Group->retrieve($group_id,
						   connection => $self->connection);
	foreach (@{ $group->members }) {
	    $users{ $_ } ||= $role;
	}
    }

    my @participants_arr =  map{$_.'='.$users{$_}} sort keys %users;

    my $participants_str = join(';', @participants_arr);
    $self->_set_participant_list( $participants_str );
    #
    # do our readback
    #
    $self->revert;
    my $class = ref($self);
    $class->retrieve([$self->id], connection => $self->connection);

    $class->_readback_check({meetingId => $self->meetingId,
			     participants => \@participants_arr},
			    [$self]);

    return $self;
}

sub _set_participant_list {
    my ($self, $participants_str, %opt) = @_;

    my %params = %{ $opt{param} || {} };

    $params{meetingId} = Elive::Util::_freeze($self->meetingId => 'Int');
    $params{users} = $participants_str;

    my $som = $self->connection->call('setParticipantList' => %params);

    $self->connection->_check_for_errors( $som );
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

    my $self;

    my $meeting_id = delete $data->{meetingId}
    or die "can't insert participant list without meetingId";
    $self = $class->retrieve([$meeting_id],
			     reuse => 1);

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

=item Elive::Entity::Participant

=back

=cut

sub _thaw {
    my ($class, $db_data, @args) = @_;

    $db_data = Elive::Util::_clone( $db_data );  # take a copy
    #
    # the soap record has a Participant property that can either
    # be of type user or group. However, Elive has seperate 'user'
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
		    if ($p->{Type}) {
			$p->{Group} = delete $p->{Participant}
		    }
		    else {
			$p->{User} = delete $p->{Participant}
		    }
		}
	    }
	}
    }

    return $class->SUPER::_thaw($db_data, @args);
}

=head1 BUGS AND RESTRICTIONS

Groups are currently being expanded on the client side, rather than being
passed through for inclusion in the participant list. This is due to current
restrictions in with the C<setParticipant> adapters etc..

=cut

1;
