#!perl
use warnings; use strict;
use Test::More tests => 3;
use Test::Exception;
use Test::Builder;

use lib '.';
use t::Elive::StandardV2;

use Elive::StandardV2::Multimedia;

our $t = Test::Builder->new;
my $class = 'Elive::StandardV2::Multimedia';

my $data = 'random junk data U(&(* 090 -0';

SKIP: {

    my %result = t::Elive::StandardV2->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 3)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive::StandardV2->connection($connection);

    my $multimedia;

  TODO: {
      local $TODO = 'insert of preload';
      lives_ok(sub {
	  $multimedia = Elive::StandardV2::Multimedia->insert(
	      {
		filename => 'elive-standardv2-test-14-multimedia-t.mpeg',
		content => $data,
		creatorId => 'elive-standardv2-tester',
	      })
	       },
	       'insert multimedia - lives'
	  );
    }

    skip('unable to continue without an object', 2)
	unless $multimedia;

    isa_ok($multimedia, $class, 'preload object');

    #
    # Body of tests to be adapted from Elive/t/24-soap-preload.t
    #

    lives_ok(sub {$multimedia->delete},'multimedia deletion - lives');
}

Elive::StandardV2->disconnect;

