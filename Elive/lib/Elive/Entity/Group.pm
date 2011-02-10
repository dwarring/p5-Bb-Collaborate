package Elive::Entity::Group;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Entity::Group::Members;

__PACKAGE__->entity_name('Group');
__PACKAGE__->collection_name('Groups');

has 'groupId' => (is => 'rw', isa => 'Str', required => 1);
__PACKAGE__->primary_key('groupId');

has 'name' => (is => 'rw', isa => 'Str',
	       documentation => 'name of the group');
__PACKAGE__->_alias(groupName => 'name', freeze => 1);

has 'members' => (is => 'rw', isa => 'Elive::Entity::Group::Members',
		  coerce => 1,
		  documentation => "ids of users in the group");
__PACKAGE__->_alias(groupMembers => 'members', freeze => 1);

has 'dn' => (is => 'rw', isa => 'Str',
	       documentation => 'LDAP Domain (where applicable)');

coerce 'Elive::Entity::Group' => from 'HashRef'
          => via {Elive::Entity::Group->construct($_,
						 %Elive::_construct_opts) };

coerce 'Elive::Entity::Group' => from 'Str'
          => via {
	      my $group_id = $_;
	      $group_id =~ s{^ \s* \* \s*}{}x;  # just in case leading '*' leaks through

	      Elive::Entity::Group->construct({groupId => $group_id}, 
					      %Elive::_construct_opts) };

=head1 NAME

Elive::Entity::Group - Elluminate Group entity instance class

=head1 DESCRIPTION

These are used to maintain user groups for general use. In particular,
for group selection of meeting participants.

The C<members> property contains the group members as an array of user IDs.

If the a site is configured for LDAP, groups are mapped to LDAP groups. 
Group access becomes read-only. The affected methods are: C<insert>, C<update>,
and C<delete>.
=cut

=head1 METHODS

=cut

=head2 insert

    #
    # insert from an array of User Ids. Elements may be integers, strings
    # and/or user objects.
    #
    my $alice = Elive::Entity::User->get_by_loginName('alice');
    my $bob = Elive::Entity::User->get_by_loginName('bob');

    my $group = Elive::Entity::Group->insert({
	name => 'Elluminati',
        # following are all ok
	members => [111111, '222222', $alice->userId, $bob ],
     },
    );

    #
    # insert from a comma separated string of user IDs
    #
    my $group = Elive::Entity::Group->insert({
	name => 'Elluminati',
	members => '111111,222222,333333',
     },
    );

Inserts a new group from data.

=cut

=head2 update 

    $group->update({members => [111111,'222222', $alice->userId, $bob]});
    $group->update({members => '111111,222222,333333'});

=cut

sub update {
    my ($self, $data, %opt) = @_;
    #
    # updateGroup barfs unless the groupName is included as a parameter.
    #
    $self->set(%$data);
    my @changed = $self->is_changed;
    push (@changed, 'name')
	unless grep {$_ eq 'name'} @changed;

    return $self->SUPER::update( undef, %opt, changed => \@changed);
}

1;
