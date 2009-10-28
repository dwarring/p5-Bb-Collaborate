package Elive::Entity::Group;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{ Elive::Entity };

use Elive::Array;

__PACKAGE__->entity_name('Group');
__PACKAGE__->collection_name('Groups');

has 'groupId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('groupId');

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'name of the group');

has 'members' => (is => 'rw', isa => 'Elive::Array', required => 1,
		  coerce => 1,
		  documentation => "ids of users in the group");

=head1 NAME

Elive::Entity::Group - Elluminate Group entity instance class

=head1 DESCRIPTION

These are used to maintain user groups for general use. In particular,
for group selection of meeting participants.

=cut

=head1 METHODS

=cut

=head2 insert

    #
    # insert from an array of integers or strings
    #
    my $group = Elive::Entity::Group->insert({
	name => 'Elluminati',
	members => [111111, 222222, 333333 ],
     },
    );

    #
    # insert from a ';' separated string of users
    #
    my $group = Elive::Entity::Group->insert({
	name => 'Elluminati',
	members => '111111;222222;333333',
     },
    );


Inserts a new group from data.

=cut

=head2 update 

    $group->update({members => '222222;333333;44444'});

=cut

sub construct {
    my $self = shift->SUPER::construct(@_);
    bless $self->members, 'Elive::Array';
    $self;
}

1;
