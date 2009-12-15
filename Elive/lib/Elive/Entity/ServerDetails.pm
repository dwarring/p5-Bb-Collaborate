package Elive::Entity::ServerDetails;
use warnings; use strict;

use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };
use Scalar::Util;

=head1 NAME

Elive::Entity::ServerDetails - Server Details entity class

=cut

__PACKAGE__->entity_name('ServerDetails');

has 'serverDetailsId' => (is => 'rw', isa => 'Str', required => 1);
__PACKAGE__->primary_key('serverDetailsId');

has 'address' => (is => 'rw', isa => 'Str');
has 'alive' => (is => 'rw', isa => 'Bool');
has 'codebase' => (is => 'rw', isa => 'Str');
has 'elsRecordingsFolder' => (is => 'rw', isa => 'Str');
has 'elmRecordingsFolder' => (is => 'rw', isa => 'Str');
has 'encoding' => (is => 'rw', isa => 'Str');
has 'maxSeats' => (is => 'rw', isa => 'Int');
has 'name' => (is => 'rw', isa => 'Str');
has 'seats' => (is => 'rw', isa => 'Int');
has 'port' => (is => 'rw', isa => 'Int');
has 'version' => (is => 'rw', isa => 'Str');
has 'lastTime' => (is => 'rw', isa => 'HiResDate');
#
# The following are introduced in Elluminate Live 9.5 (ELM 3.0).
# These are currently only supported as references, but may be
# promoted to objects in later versions of Elive.
#
has 'sessions' => (is => 'rw', isa => 'Ref');
has 'serverStatus' => (is => 'rw', isa => 'Ref');
has 'iNetAddress' => (is => 'rw', isa => 'Ref');
	
=head1 METHODS

=cut

=head2 list

    my ($server) = Elive::Entity::ServerDetails->list();

Return the server details. Note that thiere is a single record. You should
always expect to retrieve one record from each connection.

=cut

sub list {
    my $class = shift;
    my %opt = @_;

    die "filter not applicable to class $class"
	if ($opt{filter});

    my $connection = $opt{connection} || $class->connection
	|| die "not connected";

    return $class->_fetch({}, %opt);
}

1;
