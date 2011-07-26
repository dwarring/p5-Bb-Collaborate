package Elive::StandardV2::ServerVersions;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::StandardV2';

use Scalar::Util;

=head1 NAME

Elive::StandardV2::ServerVersions - Server Versions entity class

=cut

__PACKAGE__->entity_name('ServerVersions');

=head2 versionId (Int)

This version's identifier belongs to an available version of the Login Group??

=cut

has 'versionId' => (is => 'rw', isa => 'Int');

=head2 versionName (Str)

The name of the Elluminate Live! version.

=cut

has 'versionName' => (is => 'rw', isa => 'Str');

=head2 versionMaxTalkersLimit (Int)

The maximum number of talkers that the version can support.

=cut

has 'versionMaxTalkersLimit' => (is => 'rw', isa => 'Int');

=head2 versionMaxFilmersLimit (Int)

The maximum number of cameras that the version can support.

=cut

has 'versionMaxFilmersLimit' => (is => 'rw', isa => 'Int');

=head1 METHODS

=cut

=head2 get

    my $versions = Elive::StandardV2::ServerVersions->get;

Returns the server version information for the current connection.

=cut

1;
