package Elive::DAO::Singleton;
use warnings; use strict;

use Carp;

=head1 NAME

Elive::DAO::Singleton - Singleton mixin class

=cut

=head2 get

For example:

    package Elive::Entity::SomeEntity;
    use warnings; use strict;

    use Mouse;

    extends 'Elive::DAO::Singleton', 'Elive::Entity';

    #...

Then

    my $server = Elive::Entity::SomeEntity->get(connection => $connection);

Get the singleton object.

=cut


=head2 list

    my $server_list = Elive::Entity::SomeEntity->list();
    my $server_obj = $server_list->[0];

Override the list method to fetch the single element.

=cut

sub list {
    my ($class, %opt) = @_;

    croak "filter not applicable to singleton class: $class"
	if ($opt{filter});

    return $class->_fetch({}, %opt);
}

sub get {
    my ($class, %opt) = @_;

    my $object_list = $class->list(%opt);

    die "unable to get $class\n"
	unless (Elive::Util::_reftype($object_list) eq 'ARRAY'
		&& $object_list->[0]);

    return $object_list->[0];
}

1;
