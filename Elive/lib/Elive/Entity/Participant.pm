package Elive::Entity::Participant;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::DAO';

use Scalar::Util;

use Elive::Util;
use Elive::Entity::User;
use Elive::Entity::Group;
use Elive::Entity::InvitedGuest;
use Elive::Entity::Role;
use Try::Tiny;

=head1 NAME

Elive::Entity::Participant - A Single Meeting Participant

=head1 DESCRIPTION

This is a component of L<Elive::Entity::Participants>. It
contains details on a participating user, including their details and
participation role (normally 2 for a moderator or 3 for a regular participant).

=head1 METHODS

=cut

__PACKAGE__->entity_name('Participant');

has 'user' => (is => 'rw', isa => 'Elive::Entity::User|Str',
		documentation => 'User (type=0)',
		coerce => 1,
    );

has 'group' => (is => 'rw', isa => 'Elive::Entity::Group|Str',
	       documentation => 'Group of attendees (type=1)',
	       coerce => 1,
    );
# for the benefit of createSession and updateSession commands
__PACKAGE__->_alias(participant => 'user' );

has 'guest' => (is => 'rw', isa => 'Elive::Entity::InvitedGuest|Str',
		documentation => 'Guest (type=2)',
		coerce => 1,
    );
__PACKAGE__->_alias( invitedGuestId => 'guest' );

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role|Str',
	       documentation => 'Role of the user within this meeting',
	       coerce => 1,
    );

has 'type' => (is => 'rw', isa => 'Int',
	       documentation => 'type of participant; 0:user, 1:group, 2:guest'
    );

sub BUILDARGS {
    my $class = shift;
    local ($_) = shift;

    if (Scalar::Util::blessed($_)) {

	if (try {$_->isa('Elive::Entity::User')}) {
	    #
	    # coerce participant as regular user
	    #
	    return {
		user => $_,
		role => {roleId => 3},
		type => 0,
	    }
	}

	if (try {$_->isa('Elive::Entity::Group')}) {
	    #
	    # coerce to group of participants
	    #
	    return {
		group => $_,
		role => {roleId => 3},
		type => 1,
	    }
	}

	if (try {$_->isa('Elive::Entity::InvitedGuests')}) {
	    #
	    # coerce to an invited guest
	    #
	    return {
		guest => $_,
		role => {roleId => 3},
		type => 2,
	    }
	}
    }

    return $_ if Scalar::Util::reftype($_);
    #
    # Simple users:
    #     'bob=3' => user:bob, role:3, type: 0 (user)
    #     'alice' => user:bob, role:3 (defaulted), type: 0 (user)
    # A leading '*' indicates a group:
    #     '*mygroup=2' => group:mygroup, role:2 type:1 (group)
    # Invited guests are of the form: displayName(loginName)
    #     'Robert(bob)' => guest:{loginName:bob, displayName:Robert}
    #
    my %parse;

    if (m{^ \s* (.*?) \s* \( ([^\)]+) \) \s* (= (\d) \s*)? $}x) {

	$parse{guest} = {displayName => $1, loginName => $2};
	$parse{type} = 2;

	return \%parse;
    }
    elsif (m{^ \s* (\*?) \s* (.*?) \s* (= (\d) \s*)? $}x) {

	my $type = $1;

	my $id = $2;
	my $roleId = $4;
	$roleId = 3 unless defined $roleId;

	if (! $type ) {
	    $parse{user} = {userId => $id};
	    $parse{type} = 0;
	}
	elsif ($type eq '*') {
	    $parse{group} = {groupId => $id};
	    $parse{type} = 1;
	}

	$parse{role}{roleId} = $roleId;

	return \%parse;
    }

    #
    # slightly convoluted die on return to keep Perl::Critic happy
    #
    return die "'$_' not in format: userId=[0-3] or *groupId=[0-3] or guestName(guestLogin)";
}

coerce 'Elive::Entity::Participant' => from 'Str'
    => via { __PACKAGE__->new( $_) };

=head2 participant

Returns a participant. This can either be of type L<Elive::Entity::User> (type
0), L<Elive::Entity::Group> (type 1) or L<Elive::Entity::InvitedGuest> (type 2).

=cut

sub participant {
    my ($self) = @_;

    return   (! $self->type)    ? $self->user
           : ($self->type == 1) ? $self->group
	   : $self->guest;
}

=head2 stringify

Returns a string of the form 'userId=role' (users) '*groupId=role (groups),
or displayName(loginName) (guests). This value is used for comparisons,
display, etc...

=cut

sub stringify {
    my $self = shift;
    my $data = shift || $self;

    $data = $self->BUILDARGS($data);

    if (! $data->{type} ) {
	# user => 'userId'
	return Elive::Entity::User->stringify($data->{user}).'='.Elive::Entity::Role->stringify($data->{role});
    }
    elsif ($data->{type} == 1) {
	# group => '*groupId'
	return Elive::Entity::Group->stringify($data->{group}).'='.Elive::Entity::Role->stringify($data->{role});
    }
    elsif ($data->{type} == 2) {
	# guest => 'displayName(loginName)'
	return Elive::Entity::InvitedGuest->stringify($data->{guest});
    }
    else {
	# unknown
	die "unrecognised participant type: $data->{type}";
    }
}

=head1 SEE ALSO

L<Elive::Entity::ParticipantList>
L<Elive::Entity::Participants>
L<Elive::Entity::User>
L<Elive::Entity::Group>
L<Elive::Entity::InvitedGues>;
L<Elive::Entity::Role>

=cut

1;
