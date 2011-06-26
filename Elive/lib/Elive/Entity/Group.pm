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
		  documentation => "ids of users or sub-groups");
__PACKAGE__->_alias(groupMembers => 'members', freeze => 1);
__PACKAGE__->_alias(entry => 'members');

has 'dn' => (is => 'rw', isa => 'Str',
	       documentation => 'LDAP Domain (where applicable)');

sub BUILDARGS {
    my $class = shift;
    my $spec = shift;

    my $args;
    if ($spec && ! ref $spec) {
	my $group_id = $_;
	$group_id =~ s{^ \s* \* \s*}{}x;  # just in case leading '*' leaks
	$args = {groupId => $group_id};
    }
    else {
	$args = $spec;
    }

    return $args;
}

coerce 'Elive::Entity::Group' => from 'HashRef|Str'
          => via {Elive::Entity::Group->new($_) };

sub stringify {
    my $class = shift;
    my $data = shift;
    $data ||= $class if (ref $class);

    my $prefix = '';

    if (Elive::Util::_reftype($data) eq 'HASH') {
	if (exists $data->{userId}) {
	    $data = $data->{userId}
	}
	elsif (exists $data->{groupId}) {
	    $prefix = '*';
	}
    }

    return $prefix . $class->SUPER::stringify($data, @_);

}

=head1 NAME

Elive::Entity::Group - Elluminate Group entity instance class

=head1 DESCRIPTION

These are used to maintain user groups for general use. In particular,
for group selection of meeting participants.

The C<members> property contains the group members as an array of user IDs
or sub-group objects.

If the a site is configured for LDAP, groups are mapped to LDAP groups. 
Group access becomes read-only. The affected methods are: C<insert>, C<update>,
and C<delete>.
=cut

sub _freeze {
    my $class = shift;
    my $app_data = shift;

    $app_data = $class->SUPER::_freeze($app_data, @_);
    $app_data->{groupId} =~ s{^\*}{} if $app_data->{groupId};

    return $app_data;
}

sub _thaw {
    my $class = shift;
    my $db_data = shift;
    my $path = shift || '';

    return $db_data unless ref $db_data;

    return $class->SUPER::_thaw($db_data, $path, @_);
}

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

=head2 expand_members

This is a utility method that includes the sum total of all members in
the group, including those in recursively nested sub-groups. The list
is further reduced to only include unique members.

    my @all_members = $group_obj->expand_members();

=cut

sub expand_members {
    my $self = shift;
    my %seen = @_;

    my @members;

    foreach (@{ $self->members || []}) {
	my @elements;

	if (Scalar::Util::blessed($_)
	    && $_->can('groupId')
	    && $_->can('expand_members')) {
	    # recursive expansion
	    @elements = $_->expand_members(%seen)
		unless $seen{g => $_->groupId}++;
	}
	else {
	    @elements = (Elive::Util::string($_));
	}

	foreach (@elements) {
	    push(@members, $_) unless $seen{u => $_}++;
	}
    }

    @members = sort @members;
    return @members;
}

1;
