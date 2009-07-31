package Elive::Entity::Participant;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Struct;
use base qw{Elive::Struct};

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

#
# name change under 9.5
#
__PACKAGE__->_alias(participant => 'user');

sub _parse {
    my $class = shift;
    local ($_) = shift;

    return $_ if Scalar::Util::reftype($_);

    m{^ \s* (.*?) \s* (= ([0-3]) \s*)? $}x
	or die "'$_' not in format: userId=role";

    my $userId = $1;
    my $roleId = $3;
    $roleId = 3 unless defined $roleId;

    return {user => {userId => $userId},
	    role => {roleId => $roleId}};
}

coerce 'Elive::Entity::Participant' => from 'Str'
    => via { Elive::Entity::Participant->new(Elive::Entity::Participant->_parse_participant($_)) };

=head1 NAME

Elive::Entity::Participant - A Single Meeting Participant

=head1 DESCRIPTION

This class cannot be retrieved directly. Rather it is a container
class for participants in an L<Elive::Entity::ParticipantList>.

=head1 SEE ALSO

L<Elive::Entity::ParticipantList>

=cut

=head1 METHODS

=cut

=head2 stringify

Returns a string of the form userId=role. This value is used for
comparisons, sql display, etc...

=cut

sub stringify {
    my $self = shift;
    my $data = shift || $self;

    return $data
	unless Scalar::Util::refaddr($data);
    #
    # Stringify to the format used for updates: userId=role
    #
    return Elive::Entity::User->stringify($data->{user}).'='.Elive::Entity::Role->stringify($data->{role});
}

1;
