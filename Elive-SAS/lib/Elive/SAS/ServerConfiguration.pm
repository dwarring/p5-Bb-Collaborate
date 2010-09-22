package Elive::SAS::ServerConfiguration;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::SAS';

use Scalar::Util;

=head1 NAME

Elive::SAS::ServerConfiguration - Server Configuration entity class

=cut

__PACKAGE__->entity_name('ServerConfiguration');

has 'boundaryTime' => (is => 'rw', isa => 'Int');
has 'maxAvailableTalkers' => (is => 'rw', isa => 'Int');
has 'maxAvailableCameras' => (is => 'rw', isa => 'Int');
has 'raiseHandsOnEnter' => (is => 'rw', isa => 'Bool');
has 'mayUseTelephony' => (is => 'rw', isa => 'Bool');
has 'mayUseSecureSignOn' => (is => 'rw', isa => 'Bool');
has 'mustReserveSeats' => (is => 'rw', isa => 'Bool');
has 'timeZone' => (is => 'rw', isa => 'Bool');

=head1 METHODS

=cut

=head2 list

    my ($server) = Elive::Entity::ServerDetails->list();

Return the server details. Note that their is a single record. You should
always expect to retrieve one record from each connection.

=cut

1;
