package Elive::Entity::Report;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use HTML::Entities;

extends 'Elive::Entity';

use Elive::Entity::Role;

__PACKAGE__->entity_name('Report');
__PACKAGE__->collection_name('Reports');

has 'reportId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('reportId');

has 'name' => (is => 'rw', isa => 'Str',
	      documentation => 'report name');
__PACKAGE__->_alias(reportName => 'name', freeze => 1);

has 'description' => (is => 'rw', isa => 'Str',
	      documentation => 'report description');
__PACKAGE__->_alias(reportDescription => 'description', freeze => 1);

has 'xml' => (is => 'rw', isa => 'Str', required => 1,
	      documentation => 'report content');
__PACKAGE__->_alias(reportDefinition => 'xml', freeze => 1);

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role',
               documentation => 'default user role',
               coerce => 1);

has 'parentId' => (is => 'rw', isa => 'Int');

has 'ownerId' => (is => 'rw', isa => 'Int');
__PACKAGE__->_alias(reportOwner => 'ownerId', freeze => 1);

=head1 NAME

Elive::Entity::Report - Elluminate Report entity instance class

=head1 DESCRIPTION

This is the entity class for server side reports. These are visible
on the Elluminate server under the 'Reports' tab.

Please note that the C<list> method does not return the body of the
report. The report object needs to be refetched via the C<retrieve> method.

For example, to export all reports on a connected server:

    my $reports = Elive::Entity::Report->list(
    my @report_ids = map {$_->reportId} @$reports;
    #
    # listed objects don't have the report body, cull and refetch them.
    #
    $reports = undef;

    foreach my $reportId (@report_ids) {

        my $rpt = Elive::Entity::Report->retrieve([$reportId]);

	my $name = $rpt->name;
	$name =~ s/[^\w]//g;
	my $export_file = "/tmp/report_${reportId}_${name}.xml";

	open (XML, '>', $export_file)
	    or die "unable to open $export_file: $!";
	print XML $rpt->xml;
	close (XML);

    }

=cut

=head1 METHODS

=cut

=head2 update

Updates an existing report.

=cut

sub update {
    my $self = shift;
    my $update_data = shift;

    my %changed;
    #
    # always need to supply these fields to the update adapter,
    # wether or not they've changed.
    #
    @changed{$self->is_changed, 'name','description','xml','ownerId'} = undef;
    $self->SUPER::update(undef, @_, changed => [sort keys %changed]);
}

1;
