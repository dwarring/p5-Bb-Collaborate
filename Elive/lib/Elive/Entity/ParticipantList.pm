package Elive::Entity::ParticipantList;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Entity::ParticipantList::Participant;
use Elive::Entity::ParticipantList::Participants;
use Elive::Entity::User;
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

You can also use the following shortcut to add individual users:

    $participant_list->update(undef, add => ['bob=3', 'alice=3']);

The C<addParticipant> and C<setParticipantList> can have problems handling
large participants lists that are getting into the 1000s (E.g. an open forum
with a large number of eligable participants). For this reason participants are
added in batches. The default size is lots of 250 users, but this can be tuned via the batch_size option:

    $participant_list->update({participants => \@big_list},
                               batch_size => 150,
                              );

By default, the C<update> method will throw an error if it failed to add all
the requested participants, or if there were any errors during the batch
updates. You may instead chose to return and handle the results yourself:

    $participant_list->update(undef,
            add => \@big_list,
            results => \(my $results));

    my $errors = $results->errors;
    warn "error(s) adding participants: @$errors"
        if @$errors;

    my $unknown = $results->unknown;
    warn "unknown participant(s): @$unknown"
        if @$unknown;

    my $failed = $results->failed;
    if (@$failed) {
        #
        # retry failed participants at a lower batch size
        #
        $participant_list->update(undef, add => $failed,
            results => \(my $retry_results), batch_size => 10);

        my $failed_again = $retry_results->failed;
        if (@$failed_again) {
            warn "failed to add participants after retry: @$failed_again";
   
            my $fatal_errors = $retry_results->errors;
            die "fatal SOAP error(s): @$fatal_errors"
         }         
    }


This will supress the throwing of most errors and will instead return an
L<Elive::Entity::ParticipantList::Results> object.

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
    my %roles;

    foreach (@raw_participants) {
	my $participant = Elive::Entity::ParticipantList::Participant->_parse($_);
	my $userId = Elive::Entity::User->stringify( $participant->{user} );
	my $roleId = Elive::Entity::Role->stringify( $participant->{role} );
	$roles{ $userId } = $roleId;
    }

    #
    # make sure that the facilitator is included with a moderator role
    #
    $roles{ $meeting->facilitatorId } = 2;

    my $participants_str = join(';', map{$_.'='.$roles{$_}} sort keys %roles);
    $self->_set_participant_list( $participants_str );
    #
    # do our readback
    #
    $self->revert;
    my $class = ref($self);
    $class->retrieve([$self->id], connection => $self->connection);

    $class->_readback_check( $self, [{meetingId => $self->meetingId,
				     participants => $participants_str}] );

    return $self;
}

sub _set_participant_list {
    my ($self, $participants_str, %opt) = @_;

    my %params = (
	meetingId => Elive::Util::_freeze($self->meetingId => 'Int'),
	users => $participants_str,
	);

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

=item 

=cut

1;
