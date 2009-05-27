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
	
=head1 METHODS

=cut

=head2 list

    my ($server) = Elive::Entity::ServerDetails->list();

Return the server details. Note that this is a singleton record. You
should always expect to retrieve one record from the server.

=cut

sub list {
    my $class = shift;
    my %opt = @_;

    die "filter not applicable to class $class"
	if ($opt{filter});

    return $class->_fetch({}, %opt);
}

1;
