package Elive::StandardV2::ServerVersions;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::StandardV2';

use Scalar::Util;

=head1 NAME

Elive::StandardV2::ServerVersions - Server Versions entity class

=cut

__PACKAGE__->entity_name('ServerVersions');

has 'versionId' => (is => 'rw', isa => 'Int');
has 'versionName' => (is => 'rw', isa => 'Str');
has 'versionMaxTalkersLimit' => (is => 'rw', isa => 'Int');
has 'versionMaxFilmersLimit' => (is => 'rw', isa => 'Int');

=head1 METHODS

=cut

=head2 get

    my $versions = Elive::StandardV2::ServerVersions->get;

Returns the server version information for the current connection.

=cut

1;
