#!perl -T
use warnings; use strict;
use Test::More tests => 12;
use Test::Exception;
use Test::Builder;

use lib '.';
use t::Elive;

use Elive;

use XML::Simple;

my $t = Test::Builder->new;

my $class = 'Elive::Entity::Report';
use Elive::Entity::Report;

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 12)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $reports;

    lives_ok(sub {$reports = Elive::Entity::Report->list}, 'reports list method - lives');

   isa_ok($reports, 'ARRAY', 'reports list results');

    unless (@$reports) {
	#
	# a bit unexpected, because Elluminate comes with built in reports
	#
        diag("** Hmmm, No reports on this server - skipping further report tests !!!?");
        skip('No reports found!?', 5);
    };

   isa_ok($reports->[0], 'Elive::Entity::Report', 'reports[0]');

   #
   # note that the list method (listReports command) does not return the
   # list body. We need to refetch
   my $report_id;

   ok($report_id = $reports->[0]->reportId, 'reports[0] has reportId');

   my $rpt;
   lives_ok (sub {$rpt = Elive::Entity::Report->retrieve($report_id)},
                 'retrieve reports[0].id - lives');

    my $sample_xml = $rpt->xml;

    ok($sample_xml, 'reports[0].xml - populated');
    lives_ok(sub {XMLin($sample_xml)}, 'reports[0].xml is valid XML');

    if ( $ENV{ELIVE_TEST_REPORT_UPDATES} ) {
	#
	# do some live create/update/delete tests on reports
	#
	my $gen_id = t::Elive::generate_id();
	my $skeletal_xml = join('', <DATA>);
	my %report_data = (
	    name => "empty report generated by soap-report.t ($gen_id)",
	    description => 'temporary empty report, created by soap-report.t (Elive test suite, with live testing of report updates enabled)',
	    xml => $skeletal_xml,
	    );

	my $report = Elive::Entity::Report->insert(\%report_data);

	foreach (sort keys %report_data) {

	    if ($_ eq 'xml') {
		# buildargs does some stripping
		like($report->$_, qr{<jasperReport}, "inserted $_");
	    }
	    else {
		is($report->$_, $report_data{$_}, "inserted $_");
	    }
	}

      TODO: {
	  local($TODO) = 'copying of existing large report - truncating on toolkit side?';
	  lives_ok(sub {$report->update({xml => $sample_xml})},
		   'copy of live report - lives');
	};

	lives_ok(sub {$report->delete}, 'report deletion - lives');
    }
    else {
	$t->skip('skipping live report update tests')
	    for (1..5);
    }

    Elive->disconnect;

}
__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<!-- Created with iReport - A designer for JasperReports --><!DOCTYPE jasperReport PUBLIC "//JasperReports//DTD Report Design//EN" "http://jasperreports.sourceforge.net/dtds/jasperreport.dtd">
<jasperReport name="EliveEmptyTestReportPleseDelete" columnCount="1" printOrder="Vertical" orientation="Landscape" pageWidth="792" pageHeight="612" columnWidth="732" columnSpacing="0" leftMargin="30" rightMargin="30" topMargin="20" bottomMargin="20" whenNoDataType="AllSectionsNoDetail" isTitleNewPage="false" isSummaryNewPage="false" language="java" isFloatColumnFooter="false" whenResourceMissingType="Null" isIgnorePagination="false">
</jasperReport>
