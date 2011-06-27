#!perl
use warnings; use strict;
use Test::More tests => 60;
use Test::Exception;
use Test::Builder;

use lib '.';
use t::Elive;

use Elive;
use Elive::Entity::Preload;
use Elive::View::Session;
use Elive::Util;

use File::Spec qw();
use File::Temp qw();

our $t = Test::Builder->new;
my $class = 'Elive::Entity::Preload' ;

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+';
$data[1] = join('',map {pack('C', $_)} (0..255));

for (0..1) {
    #
    # belongs in util tests
    is(Elive::Util::_hex_decode(Elive::Util::_hex_encode($data[$_])), $data[$_], "hex encode/decode round-trip [$_]");   
}

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 58)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my @preloads;

    $preloads[0] = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test.wbd',
	ownerId => Elive->login,
	data => $data[0],
    },
    );

    isa_ok($preloads[0], $class, 'preload object');

    is($preloads[0]->type, 'whiteboard', "preload type is 'whiteboard'");
    is($preloads[0]->mimeType, 'application/octet-stream','expected value for mimeType (guessed)');
    ok($preloads[0]->name =~ m{test(\.wbd)?$}, 'preload name, as expected');
    is($preloads[0]->ownerId, Elive->login->userId, 'preload ownerId, as expected');
    is($preloads[0]->size, length($data[0]), 'preload size, as expected');

    my $data_download = $preloads[0]->download;

    ok($data_download, 'got data download');
    is($data_download, $data[0], 'download data matches upload');

    ok (my $preload_id = $preloads[0]->preloadId, 'got preload id');

    $preloads[0] = undef;

    ok($preloads[0] = Elive::Entity::Preload->retrieve([$preload_id]), 'preload retrieval');

    #
    # try upload from a file
    #

    my ($fh, $filename)
	= File::Temp::tempfile('elive-t-24-soap-preload-XXXXXXXX',
			       SUFFIX => '.wav',
			       DIR => File::Spec->tmpdir() );

    $fh->binmode();
    print $fh $data[1];
    close $fh;

    $preloads[1] = Elive::Entity::Preload->upload( $filename );
    unlink( $filename );

    $data_download = $preloads[1]->download;
       
    ok($data_download, 'got data download');
    is($data_download, $data[1], 'download data matches file upload');

    is($preloads[1]->type, 'media','expected value for mimeType (uploaded file)');

    is($preloads[1]->mimeType, 'audio/x-wav','expected value for mimeType (defaulted)');
    is($preloads[1]->ownerId, Elive->login->userId,'preload owner id defaults to login user');

    $preloads[2] = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test_unknown_ext.xyz',
	ownerId => Elive->login,
	mimeType => 'video/mpeg',
	data => $data[1],
    },
    );

    is($preloads[2]->mimeType, 'video/mpeg','expected value for mimeType (set)');

    $preloads[3] = Elive::Entity::Preload->upload(
    {
	type => 'plan',
	name => 'test_plan.elpx',
	ownerId => Elive->login,
	data => $data[1],
    },
    );

    is($preloads[3]->type, 'plan','expected type (plan)');
    is($preloads[3]->mimeType, 'application/octet-stream','expected mimeType for plan');

    dies_ok(sub{$preloads[3]->update({name => 'test_plan.elpx updated'})}, 'preload update - not available');

    $data_download = $preloads[3]->download;

    is($data_download, $data[1], 'plan download matches upload');

    my $check;

    #
    # use three mechanisims to associate meetings with preloads
    #
    # 1. session insert
    # 2. session update
    # 3. add_preload method on meeting

    ok(my $session = Elive::View::Session->insert({
	name => 'created by t/soap-preload.t',
	facilitatorId => Elive->login,
	start => time() . '000',
	end => (time()+900) . '000',
	privateMeeting => 1,
	add_preload => [ $preloads[0], $preloads[1] ],
    }),
	'inserted session');

    # preload 0,1 - added at session setup

    lives_ok(sub {$check = $session->check_preload($preloads[0])},
	     'session->check_preload - lives');

    ok($check, 'check_preload following session creation');

    # preload 2 - meeting level access

    lives_ok(sub {$check = $session->meeting->check_preload($preloads[2])},
	     'session->check_preloads - lives');

    ok(!$check, 'check_preload prior to add - returns false');

    lives_ok(sub {$session->meeting->add_preload($preloads[2])},
	     'adding meeting preloads - lives');

    lives_ok(sub {$check = $session->meeting->check_preload($preloads[2])},
	     'meeting->check_preloads - lives');

    ok($check, 'check_meeting after add - returns true');

    # just to define what happens if we attempt to re-add a preload
    dies_ok(sub {$check = $session->meeting->add_preload($preloads[2])},
	     're-add of preload to session - dies');

    # preload 3 - session level access

    lives_ok(sub {$check = $session->check_preload($preloads[3])},
	     'session->check_preloads - lives');

    ok(!$check, 'check_preload prior to add - returns false');

    lives_ok(sub {$session->update({add_preload => $preloads[3]})},
	     'adding meeting preloads - lives');

    lives_ok(sub {$check = $session->check_preload($preloads[3])},
	     'meeting->check_preloads - lives');

    ok($check, 'check_meeting after add - returns true');

    my $preloads_list;
    lives_ok(sub {$preloads_list = $session->list_preloads},
	     'list_session_preloads - lives');

    isa_ok($preloads_list, 'ARRAY', 'preloads list');

    is(@$preloads_list, scalar @preloads, 'meeting has expected number of preloads');

    do {
	my @preload_ids = map {$_->preloadId} @preloads;
	my $n = 0;

	foreach (@$preloads_list) {
	    isa_ok($_, 'Elive::Entity::Preload', "preload_list[$n]");
	    my $preload_id = $_->preloadId;
	    ok((grep {$_ eq $preload_id} @preload_ids), "preload_id[$n] - as expected");
	    ++$n;
	    
	}
    };

    #
    # verify that we can remove a preload
    #
    lives_ok( sub {$session->remove_preload($preloads[1])},
	      'meeting->remove_preload - lives');

    lives_ok(sub {$preloads[0]->delete}, 'preloads deletion - lives');
    #
    # just directly delete the second preload
    #
    # the meeting should be left with one preload
    #

    my $preloads_list_2;
    lives_ok(sub {$preloads_list_2 = $session->list_preloads},
             'list_meeting_preloads - lives');

    isa_ok($preloads_list_2, 'ARRAY', 'preloads list');

    ok(@$preloads_list_2 == scalar(@preloads)-2, 'meeting still has expected number of preloads');

    $session->delete;

    dies_ok(sub {$preloads[0]->retrieve([$preload_id])}, 'attempted retrieval of deleted preload - dies');

    my $server_details = Elive->server_details;
    if ($server_details->version ge '10.0.0') {
	$t->skip('skipping known Elluminate v10.0.0+ bugs')
	    for (1..2);
    }
    else {

	lives_ok( sub {
	    push (@preloads, Elive::Entity::Preload->upload(
		      {
			  type => 'whiteboard',
			  name => 'test_no_extension',
			  ownerId => Elive->login,
			  mimeType => 'video/mpeg',
			  data => $data[1],
		  },
		  ))},
		  'upload of preload with no extension - lives'
	    );

	is($preloads[-1]->mimeType, 'video/mpeg','expected value for mimeType (set, no-extension)');
    }

    for my $i (1 .. $#preloads) {
	$preloads[$i]->delete;
    }

    if (my $path_on_server = $ENV{ELIVE_TEST_PRELOAD_SERVER_PATH}) {
	diag 'running preload import tests ($ELIVE_TEST_PRELOAD_SERVER_PATH set)';
	diag "importing server-side file: $path_on_server";
	my $basename = File::Basename::basename($path_on_server);
	my $imported_preload;

	lives_ok( sub {
	    $imported_preload = Elive::Entity::Preload->import_from_server(
		{
		    name => $basename,
		    ownerId => Elive->login,
		    fileName => $path_on_server,
		},
		);
		  },
		  'import_from_server - lives',     
         );

	isa_ok($imported_preload, 'Elive::Entity::Preload', 'imported preload');

	diag 'imported preload has size: '.$imported_preload->size.' and type '.$imported_preload->type.' ('.$imported_preload->mimeType.')';

	is($imported_preload->name, $basename, 'imported preload name as expected');
	ok($imported_preload->size > 0, 'imported preload has non-zero size');
	lives_ok (sub {$imported_preload->delete}, 'imported preload delete - lives');
    }
    else {
	$t->skip('skipping import_preload_test (set ELIVE_TEST_PRELOAD_SERVER_PATH to run)')
	    for (1 .. 5);
    }
}

Elive->disconnect;

