package Elive::Entity::ParticipantList::Participant;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Struct';

use Scalar::Util;

use Elive::Util;
use Elive::Entity::User;
use Elive::Entity::Role;
use Elive::Entity::Group;

=head1 NAME

Elive::Entity::ParticipantList::Participant - A Single Meeting Participant

=head1 DESCRIPTION

This is a component of L<Elive::Entity::ParticipantList::Participants>. It contains details on a
participating user, including their details and participation role (normally 2 for a moderator or 3
for a regular participant).

=head1 METHODS

=cut

__PACKAGE__->entity_name('Participant');

has 'user' => (is => 'rw', isa => 'Elive::Entity::User|Str',
	       documentation => 'User or group attending the meeting',
	       coerce => 1,
    );

has 'group' => (is => 'rw', isa => 'Elive::Entity::Group|Str',
		documentation => 'User or group attending the meeting',
		coerce => 1,
    );

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role|Str',
	       documentation => 'Role of the user within this meeting',
	       coerce => 1,
    );

has 'type' => (is => 'rw', isa => 'Int',
	       documentation => 'type of participant; 0: user, 1: group'
    );

sub _parse {
    my $class = shift;
    local ($_) = shift;

    if (Scalar::Util::blessed($_)) {

	if (eval{$_->isa('Elive::Entity::User')}) {
	    #
	    # coerce participant as regular user
	    #
	    return {
		user => $_,
		role => {roleId => 3},
		type => 0,
	    }
	}

	if (eval{$_->isa('Elive::Entity::Group')}) {
	    #
	    # coerce to group of participants
	    #
	    return {
		group => $_,
		role => {roleId => 3},
		type => 1,
	    }
	}
    }

    return $_ if Scalar::Util::reftype($_);

    # A leading '*' indicates an LDAP group. Examples:
    # 'bob=3' => user:bob, role:3, type: 0 (user)
    # 'alice' => user:bob, role:3 (defaulted), type: 0 (user)
    # '*mygroup=2' => group:mygroup, role:2 type:1 (group)

    m{^ \s* (\*?) \s* (.*?) \s* (= (\d) \s*)? $}x
	or die "'$_' not in format: userId=role";

    my $is_group = $1;
    my $id = $2;
    my $roleId = $4;
    $roleId = 3 unless defined $roleId;

    my %parse = $is_group
	? (group => {groupId => $id}, type => 1)
	: (user => {userId => $id}, type => 0);

    $parse{role}{roleId} = $roleId;

    return \%parse;
}

coerce 'Elive::Entity::ParticipantList::Participant' => from 'Str'
    => via { Elive::Entity::ParticipantList::Participant->new(Elive::Entity::ParticipantList::Participant->_parse_participant($_)) };

=head2 participant

Returns a participant. This can either be of type L<Elive::Entity::User> (type: 0), or
L<Elive::Entity::Group> (type 1).

=cut

sub participant {
    my ($self) = @_;

    return $self->type? $self->group: $self->user;
}

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
    if ($data->{type} && $data->{type} == 1) {
	return '*' . Elive::Entity::Group->stringify($data->{group}).'='.Elive::Entity::Role->stringify($data->{role});
    }
    else {
	return Elive::Entity::User->stringify($data->{user}).'='.Elive::Entity::Role->stringify($data->{role});
    }
}

=head1 SEE ALSO

L<Elive::Entity::ParticipantList> L<Elive::Entity::ParticipantList::Participants>

=cut

1;
