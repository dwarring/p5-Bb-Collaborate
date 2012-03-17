#!perl -T
use warnings; use strict;
use Test::More tests => 12;
use Test::Fatal;

use lib '.';
use t::Elive::StandardV3;

use Elive::StandardV3::Multimedia;
use Elive::StandardV3::Session;
use Elive::Util;

our $t = Test::More->builder;
my $class = 'Elive::StandardV3::Multimedia';

my $data = 'unplayable junk data U(&(* 090 -0';

SKIP: {

    my %result = t::Elive::StandardV3->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 12)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive::StandardV3->connection($connection);

    my $multimedia;

  do {
      is( exception {
	  $multimedia = Elive::StandardV3::Multimedia->upload(
	      {
		filename => 'elive-standardv3-soap-session-multimedia-t.mpeg',
		content => $data,
                description => 'created by standard v3 t/soap-multimedia.t',
		creatorId => 'elive-standardv3-tester',
	      })
	       } => undef,
	       'insert multimedia - lives'
	  );
  };

    skip('unable to continue without an object', 4)
	unless $multimedia;

    isa_ok($multimedia, $class, 'preload object');

    my $multimedia_id = $multimedia->multimediaId;
    ok($multimedia_id, 'got multimedia id');

    my $multimedia_list;

    # you need to supply a creatator id
    is( exception {$multimedia_list = Elive::StandardV3::Multimedia->list({multimediaId => $multimedia_id, creatorId => 'elive-standardv3-tester'})} => undef,  'retrieve multimedia - lives');

     skip('unable to continue without an object', 4)
	unless $multimedia_list && $multimedia_list->[0]; 

    is($multimedia_list->[0]->creatorId, 'elive-standardv3-tester', 'preload creatorId, as expected');
    is($multimedia_list->[0]->size, length($data), 'preload size, as expected');
    is($multimedia_list->[0]->description, 'created by standard v3 t/soap-multimedia.t', 'description, as expected'); 

    my $start_time = Elive::Util::next_quarter_hour();
    my $end_time = Elive::Util::next_quarter_hour( $start_time);

    ok(my $session = Elive::StandardV3::Session->insert({
	sessionName => 'created by t/soap-multimedia.t',
	creatorId => Elive::StandardV3->connection->user,
	startTime => $start_time . '000',
	endTime => $end_time . '000',
	nonChairList => [qw(alaice bob)],
    }),
	'inserted session');

    is( exception {
	$session->set_multimedia( $multimedia_list )
	} => undef,
	'$session->set_multimedia(...) - lives');

    isnt( exception {$multimedia_list->[0]->delete} => undef, 'deletion of referenced multimedia - dies');

       is( exception {
	   $session->remove_multimedia($multimedia_list->[0]);
	} => undef,
	'$session->removed_multimedia - lives'); 

    is( exception {$multimedia_list->[0]->delete} => undef, 'deletion of unreferenced multimedia - lives');

    is( exception {$session->delete} => undef, 'deletion of session - lives');

}

Elive::StandardV3->disconnect;

