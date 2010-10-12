package Elive::Entity::ParticipantList::Participant;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Struct';

use Scalar::Util;

use Elive::Util;
use Elive::Entity::User;
use Elive::Entity::Role;

__PACKAGE__->entity_name('Participant');

has 'user' => (is => 'rw', isa => 'Elive::Entity::User|Str',
	       documentation => 'User attending the meeting',
	       coerce => 1,
    );

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role|Str',
	       documentation => 'Role of the user within this meeting',
	       coerce => 1,
    );

has 'type' => (is => 'rw', isa => 'Int',
	       documentation => 'Not sure what this is',
    );

#
# name change under 9.5
#
__PACKAGE__->_alias(participant => 'user');

sub _parse {
    my $class = shift;
    local ($_) = shift;

    if (Scalar::Util::blessed($_)
	&& eval{$_->isa('Elive::Entity::User')}
	) {
	#
	# coerce user to participant
	#
	return {user => $_,
		role => {roleId => 3}};
    }

    return $_ if Scalar::Util::reftype($_);

    m{^ \s* (.*?) \s* (= (\d) \s*)? $}x
	or die "'$_' not in format: userId=role";

    my $userId = $1;
    my $roleId = $3;
    $roleId = 3 unless defined $roleId;

    return {user => {userId => $userId},
	    role => {roleId => $roleId}};
}

coerce 'Elive::Entity::ParticipantList::Participant' => from 'Str'
    => via { Elive::Entity::ParticipantList::Participant->new(Elive::Entity::ParticipantList::Participant->_parse_participant($_)) };

=head1 NAME

Elive::Entity::ParticipantList::Participant - A Single Meeting Participant

=head1 DESCRIPTION

This is a component of L<Elive::Entity::ParticipantList::Participants>. It contains details on a
participating user, including their details and participation role (normally 2 for a moderator or 3
for a regular participant).

=head1 METHODS

=cut

=head2 stringify

Returns a string of the form userId=role. This value is used for
comparisons, sql display, etc...

=cut

sub stringify {
    my $self = shift;
    my $data = shift || $self;

    $data = $self->_parse($data)
	unless Scalar::Util::refaddr($data);
    #
    # Stringify to the format used for updates: userId=role
    #
    return Elive::Entity::User->stringify($data->{user}).'='.Elive::Entity::Role->stringify($data->{role});
}

=head1 SEE ALSO

L<Elive::Entity::ParticipantList> L<Elive::Entity::ParticipantList::Participants>

=cut

1;
