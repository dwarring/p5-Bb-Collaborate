package Elive::Entity::Report;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use HTML::Entities;

use Elive::Entity;
use base qw{ Elive::Entity };

__PACKAGE__->entity_name('Report');
__PACKAGE__->collection_name('Reports');

has 'reportId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('reportId');

has 'name' => (is => 'rw', isa => 'Str',
	      documentation => 'report name');

has 'description' => (is => 'rw', isa => 'Str',
	      documentation => 'report description');

has 'xml' => (is => 'rw', isa => 'Str', required => 1,
	      documentation => 'report content');

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role',
               documentation => 'default user role',
               coerce => 1);

has 'parentId' => (is => 'rw', isa => 'Int');

has 'ownerId' => (is => 'rw', isa => 'Int');

=head1 NAME

Elive::Entity::Report - Elluminate Report entity instance class

=head1 DESCRIPTION

This is the entity class for server side reports.

=cut

=head1 METHODS

=cut

sub _thaw {
    my $class = shift;
    my $db_data = shift;
  
    my $data = $class->SUPER::_thaw($db_data, @_);

    for (grep {defined} $data->{xml}) {
	$_ = HTML::Entities::decode_entities($_);
	s{\015$}{}mg
	}

    return $data;
}

## following is experimental!!

sub _tba_build {
    my $self = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $self->connection
	or die "not connected";

    my $report_id = $opt{report_id};

    $report_id ||= $self->reportId
	if ref($self);

    die "unable to determine report_id"
	unless $report_id;

    my %soap_params = %{$opt{params} || {}};

    $soap_params{reportId} = $report_id;

    my $adapter = $self->check_adapter('buildReport');

    my $som = $connection->call($adapter,
				%soap_params,
				);

    $self->_check_for_errors($som);

    my $results = $self->_unpack_as_list($som->result);

    return @$results && Elive::Util::_thaw($results->[0], 'Str');
}

1;
