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

Return the server details. Note that this is a singleton record. You should
always expect to retrieve one record from the server.

=cut

sub list {
    my $class = shift;
    my %opt = @_;

    die "filter not applicable to class $class"
	if ($opt{filter});

    my $connection = $opt{connection} || $class->connection
	|| die "not connected";

    my $server_details_list;

    if (($ENV{ELIVE_FORCE}||'') eq '9.5.0') {
	#
	# Elluminate Live release 9.5.0 is not currently supported due
	# to some unresolved problems. In particular getServerDetails
        # and getMeetingsByDate. Set ELIVE_FORCE to dummy up a server
	# details record, so we can at least connect and login to the
	# server.
	#
	my $looks_like_elm_9_5 = defined $connection->login->domain;

	if ($looks_like_elm_9_5) {
	    #
	    # Ouch, we haven't been able to a server details record,
	    # but this is broken in elm 9.5. Return a dummy, so that
	    # we can at least keep going!
   
	    $server_details_list = [Elive::Entity::ServerDetails->new({serverDetailsId => 'server-details-broken-in-elm-9.5', version => '9.5.0'})];
	}
    }

    $server_details_list ||= $class->_fetch({}, %opt);

    return $server_details_list;
}

1;
