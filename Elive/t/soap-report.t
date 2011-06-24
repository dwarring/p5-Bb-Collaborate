#!perl
use warnings; use strict;
use Test::More tests => 7;
use Test::Exception;

use lib '.';
use t::Elive;

use Elive;

use XML::Simple;

my $class = 'Elive::Entity::Report';
use Elive::Entity::Report;

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 7)
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
   lives_ok (sub {$rpt = Elive::Entity::Report->retrieve([$report_id])},
                 'retrieve reports[0].id - lives');

    ok($rpt->xml, 'reports[0].xml - populated');
    lives_ok(sub {XMLin($rpt->xml)}, 'reports[0].xml is valid XML');

    Elive->disconnect;

}


