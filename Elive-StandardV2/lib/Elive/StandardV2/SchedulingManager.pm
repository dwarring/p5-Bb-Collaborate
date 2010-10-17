package Elive::StandardV2::SchedulingManager;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::StandardV2';

use Scalar::Util;

=head1 NAME

Elive::StandardV2::SchedulingManager - Scheduling Manager entity class

=cut

__PACKAGE__->entity_name('SchedulingManager');

has 'manager' => (is => 'rw', isa => 'Str');
has 'version' => (is => 'rw', isa => 'Str');

=head1 METHODS

=cut

=head2 list

    my ($server) = Elive::Entity::ServerDetails->list();

Return the server details. Note that their is a single record. You should
always expect to retrieve one record from each connection.

=cut

sub list {
    my ($class, %opt) = @_;

    return $class->_fetch({}, %opt);
}

1;
