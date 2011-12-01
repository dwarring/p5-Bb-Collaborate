#!perl -T
use warnings; use strict;
use Test::More tests => 3;
use Test::Fatal;
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
      is( exception {
	  $multimedia = Elive::StandardV2::Multimedia->upload(
	      {
		filename => 'elive-standardv2-soap-session-multimedia-t.mpeg',
		content => $data,
                description => 'created by t/soap-multimedia.t',
		creatorId => 'elive-standardv2-tester',
	      })
	       } => undef,
	       'insert multimedia - lives'
	  );
    }

    skip('unable to continue without an object', 2)
	unless $multimedia;

    isa_ok($multimedia, $class, 'preload object');

    #
    # Body of tests to be adapted from Elive/t/soap-preload.t
    #

    is( exception {$multimedia->delete} => undef, 'multimedia deletion - lives');
}

Elive::StandardV2->disconnect;

