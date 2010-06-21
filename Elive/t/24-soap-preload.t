#!perl
use warnings; use strict;
use Test::More tests => 49;
use Test::Exception;
use Test::Builder;

use lib '.';
use t::Elive;

BEGIN {
    use_ok('Elive');
    use_ok( 'Elive::Entity::Preload' );
    use_ok( 'Elive::Entity::Meeting' );
    use_ok ('Elive::Util');
};

our $t = Test::Builder->new;
my $class = 'Elive::Entity::Preload' ;

my @data;
$data[0] = 'the quick brown fox. %%(&)+(*)+*(_+';
$data[1] = join('',map {pack('C', $_)} (0..255));

for (0..1) {
    #
    # belongs in util tests
    ok(Elive::Util::_hex_decode(Elive::Util::_hex_encode($data[$_])) eq $data[$_], "hex encode/decode round-trip [$_]");   
}

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	43)
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

    ok($preloads[0]->type eq 'whiteboard', "preload type is 'whiteboard'");
    ok($preloads[0]->mimeType eq 'application/octet-stream','expected value for mimeType (guessed)');
    ok($preloads[0]->name =~ m{test(\.wbd)?$}, 'preload name, as expected');
    ok($preloads[0]->ownerId eq Elive->login->userId, 'preload ownerId, as expected');

    my $data_download = $preloads[0]->download;

    ok($data_download, 'got data download');
    ok($data_download eq $data[0], 'download data matches upload');

    ok (my $preload_id = $preloads[0]->preloadId, 'got preload id');

    $preloads[0] = undef;

    ok($preloads[0] = Elive::Entity::Preload->retrieve([$preload_id]), 'preload retrieval');

    ok(my $meeting = Elive::Entity::Meeting->insert({
	name => 'created by t/24-soap-preload.t',
	facilitatorId => Elive->login,
	start => time() . '000',
	end => (time()+900) . '000',
	privateMeeting => 1,
    }),
	'inserted meeting');

    $preloads[1] = Elive::Entity::Preload->upload(
    {
	type => 'media',
	name => 'test.wav',
	ownerId => Elive->login,
	data => $data[1],
    },
    );

    ok($preloads[1]->mimeType eq 'audio/x-wav','expected value for mimeType (guessed)');

    $preloads[2] = Elive::Entity::Preload->upload(
    {
	type => 'whiteboard',
	name => 'test_unknown_ext.xyz',
	ownerId => Elive->login,
	mimeType => 'video/mpeg',
	data => $data[1],
    },
    );

    ok($preloads[2]->mimeType eq 'video/mpeg','expected value for mimeType (set)');

    $preloads[3] = Elive::Entity::Preload->upload(
    {
	type => 'plan',
	name => 'test_plan.elpx',
	ownerId => Elive->login,
	data => $data[1],
    },
    );

    ok($preloads[3]->type eq 'plan','expected type (plan)');
    ok($preloads[3]->mimeType eq 'application/octet-stream','expected mimeType for plan');

    dies_ok(sub{$preloads[3]->update({name => 'test_plan.elpx updated'})}, 'preload update - not available');

    $data_download = $preloads[3]->download;

    ok($data_download eq $data[1], 'plan download matches upload');

    my $check;

    lives_ok(sub {$check = $meeting->check_preload($preloads[0])},
	     'meeting->check_preloads - lives');

    ok(!$check, 'check_meeting prior to add - returns false');

    lives_ok(sub {$meeting->add_preload($_) for (@preloads)},
	     'adding meeting preloads - lives');

    lives_ok(sub {$check = $meeting->check_preload($preloads[0])},
	     'meeting->check_preloads - lives');

    ok($check, 'check_meeting after add - returns true');

    my $preloads_list;
    lives_ok(sub {$preloads_list = $meeting->list_preloads},
	     'list_meeting_preloads - lives');

    isa_ok($preloads_list, 'ARRAY', 'preloads list');

    ok(@$preloads_list == scalar @preloads, 'meeting has expected number of preloads');

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
    lives_ok( sub {$meeting->remove_preload($preloads[1])},
	      'meeting->remove_preload - lives');

    lives_ok(sub {$preloads[0]->delete}, 'preloads deletion - lives');
    #
    # just directly delete the second preload
    #
    # the meeting should be left with one preload
    #

    my $preloads_list_2;
    lives_ok(sub {$preloads_list_2 = $meeting->list_preloads},
             'list_meeting_preloads - lives');

    isa_ok($preloads_list_2, 'ARRAY', 'preloads list');

    ok(@$preloads_list_2 == scalar(@preloads)-2, 'meeting has expected number of preloads');

    $meeting->delete;

    dies_ok(sub {$preloads[0]->retrieve([$preload_id])}, 'attempted retrieval of deleted preload - dies');

    for my $i (1 .. $#preloads) {
	$preloads[$i]->delete;
    }

    if (my $path_on_server = $ENV{ELIVE_TEST_PRELOAD_SERVER_PATH}) {
	diag 'running preload import tests ($ELIVE_TEST_PRELOAD_SERVER_PATH set)';
	diag "importing from server: $path_on_server";
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

	ok($imported_preload->name eq $basename, 'imported preload name as expected');
	ok($imported_preload->size > 0, 'imported preload has non-zero size');
	lives_ok (sub {$imported_preload->delete}, 'imported preload delete - lives');
    }
    else {
	$t->skip('skipping import_preload_test (set ELIVE_TEST_PRELOAD_SERVER_PATH to run)')
	    for (1 .. 5);
    }
}

Elive->disconnect;

