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

has 'group' => (is => 'rw', isa => 'Elive::Entity::Group|Str',
		documentation => 'User (type=0)',
		coerce => 1,
    );

has 'user' => (is => 'rw', isa => 'Elive::Entity::User|Str',
	       documentation => 'Group of attendees (type=1)',
	       coerce => 1,
    );

has 'guest' => (is => 'rw', isa => 'Elive::Entity::InvitedGuests|Str',
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

	if (eval{$_->isa('Elive::Entity::InvitedGuests')}) {
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
    # A leading '*' indicates an LDAP group:
    #     '*mygroup=2' => group:mygroup, role:2 type:1 (group)
    # A leading '+' indicates invited guests ids
    #     '+invitedGuestId=2' => guest:, role:2 type:1 (group)
    #

    if (m{^ \s* ([\*\+]?) \s* (.*?) \s* (= (\d) \s*)? $}x) {

	my @types = qw{user group guest};

	my $type = $1;

	my $id = $2;
	my $roleId = $4;
	$roleId = 3 unless defined $roleId;

	my %parse;

	if (! $type ) {
	    $parse{user} = {userId => $id};
	    $parse{type} = 0;
	}
	elsif ($type eq '*') {
	    $parse{group} = {groupId => $id};
	    $parse{type} = 1;
	}
	elsif ($type eq '+') {
	    $parse{guest} = {invitedGuestId => $id};
	    $parse{type} = 2;
	}

	$parse{role}{roleId} = $roleId;

	return \%parse;
    }

    #
    # slightly convoluted die on return to keep Perl::Critic happy
    #
    return die "'$_' not in format: userId=[0-4] or *groupId=[0-4] or +invitedGuestId=[0-4]";
}

coerce 'Elive::Entity::ParticipantList::Participant' => from 'Str'
    => via { __PACKAGE__->new( __PACKAGE__->_parse_participant($_) ) };

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
    if (! $data->{type} ) {
	# user
	return Elive::Entity::User->stringify($data->{user}).'='.Elive::Entity::Role->stringify($data->{role});
    }
    elsif ($data->{type} == 1) {
	# group
	return '*' . Elive::Entity::Group->stringify($data->{group}).'='.Elive::Entity::Role->stringify($data->{role});
    }
    elsif ($data->{type} == 2) {
	# guest
	return '+' . Elive::Entity::InvitedGuests->stringify($data->{guest}).'='.Elive::Entity::Role->stringify($data->{role});
    }
    else {
	# unknown
	die "unrecognised type: $data->{type}";
    }
}

=head1 SEE ALSO

L<Elive::Entity::ParticipantList> L<Elive::Entity::ParticipantList::Participants>

=cut

1;
