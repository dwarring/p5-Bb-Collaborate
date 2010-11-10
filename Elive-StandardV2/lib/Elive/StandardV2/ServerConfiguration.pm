package Elive::StandardV2::ServerConfiguration;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::StandardV2';

use Scalar::Util;

=head1 NAME

Elive::StandardV2::ServerConfiguration - Server Configuration entity class

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

=head2 get

    my $server_config = Elive::StandardV2::ServerConfiguration->get();

Return the server configuration details.

=cut

1;
