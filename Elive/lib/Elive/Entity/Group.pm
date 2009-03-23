package Elive::Entity::Group;

use Moose;
use Elive::Entity;
use base qw{ Elive::Entity };

__PACKAGE__->entity_name('Group');
__PACKAGE__->collection_name('Groups');

has 'groupId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('groupId');

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'name of the group');

has 'members' => (is => 'rw', isa => 'ArrayRef[Int]', required => 1,
		  documentation => "ids of users in the group");

##
## Considering this. Maybe with Elive 0.02 or 0.03
## has 'members' => (is => 'rw', isa => 'ArrayRef[Elive::Entity::User]', required => 1);

=head1 NAME

Elive::Entity::Group - Elluminate Group entity instance class

=cut

1;
