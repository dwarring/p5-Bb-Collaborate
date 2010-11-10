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

=head2 get

    my $scheduling_manager = Elive::StandardV2::SchedulingManager->get();

Return the scheduling manager details.

=cut

1;
