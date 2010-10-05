package Elive::API::ServerConfiguration;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::API';

use Scalar::Util;

=head1 NAME

Elive::API::ServerConfiguration - Server Configuration entity class

=cut

__PACKAGE__->entity_name('ServerConfiguration');

has 'boundaryTime' => (is => 'rw', isa => 'Int');
has 'maxAvailableTalkers' => (is => 'rw', isa => 'Int');
has 'maxAvailableCameras' => (is => 'rw', isa => 'Int');
has 'raiseHandOnEnter' => (is => 'rw', isa => 'Bool');
has 'mayUseTelephony' => (is => 'rw', isa => 'Bool');
has 'mayUseSecureSignOn' => (is => 'rw', isa => 'Bool');
has 'mustReserveSeats' => (is => 'rw', isa => 'Bool');
has 'timeZone' => (is => 'rw', isa => 'Bool');

=head1 METHODS

=cut

=head2 list

    my $server_config = Elive::API::ServerConfiguration->get();

Return the server configuration details.

=cut

1;
