package Elive::StandardV2::ServerVersions;
use warnings; use strict;

use Mouse;

extends 'Elive::DAO::Singleton','Elive::StandardV2';

use Scalar::Util;

=head1 NAME

Elive::StandardV2::ServerVersions - Server Versions entity class

=cut

=head1 DESCRIPTION

This class information regarding the Elluminate I<Live!> versions to which you have access.

=cut

__PACKAGE__->entity_name('ServerVersions');

=head1 PROPERTIES

=head2 versionId (Int)

The version number as a 4 digit integer, e.g. C<1002>.

=cut

has 'versionId' => (is => 'rw', isa => 'Int');

=head2 versionName (Str)

The version in XX.X.X format, e.g. C<10.0.2>.

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

    my $server_version = Elive::StandardV2::ServerVersions->get;
    print "ELM version is: ".$server_version->versionName."\n";

Returns the server version information for the current connection.

=cut

=head2 list

    my @server_versions = Elive::StandardV2::ServerVersions->list;

The C<list> method can be used for sites with multiple session servers.

=cut

1;
