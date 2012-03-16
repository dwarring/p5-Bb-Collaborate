#!perl -T
use warnings; use strict;
use Test::More tests => 3;
use Test::Fatal;

use lib '.';
use t::Elive::StandardV2;

use Elive::StandardV2::Presentation;

our $t = Test::More->builder;
my $class = 'Elive::StandardV2::Presentation';

my $data = 'random junk data U(&(* 090 -0';

SKIP: {

    my %result = t::Elive::StandardV2->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 3)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive::StandardV2->connection($connection);

    my $presentation;

  do {
      local($TODO) = 'UploadRespositoryPresentation - mixed up filename and description in response?';
      is( exception {
	  $presentation = Elive::StandardV2::Presentation->upload(
	      {
		filename => 'elive-standardv2-soap-session-presentation-t.wbd',
		content => $data,
                description => 'created by t/soap-presentation.t',
		creatorId => 'elive-standardv2-tester',
	      })
	       } => undef,
	       'insert presentation - lives'
	  );
  };

    skip('unable to continue without an object', 2)
	unless $presentation;

    isa_ok($presentation, $class, 'preload object');

    #
    # Body of tests to be adapted from Elive/t/soap-preload.t
    #

    is( exception {$presentation->delete} => undef, 'presentation deletion - lives');
}

Elive::StandardV2->disconnect;

