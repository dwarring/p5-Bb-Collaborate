#!perl
use warnings; use strict;
use Test::More tests => 12;
use Test::Fatal;

use lib '.';
use t::Elive::StandardV2;

use Elive::StandardV2;
# don't 'use' anything here! We're testing Elive's ability to load the
# other required classes (Elive::Connection, Elive::Entity::User etc)

our $t = Test::More->builder;

SKIP: {

    my %result = t::Elive::StandardV2->test_connection(noload => 1);
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 12)
	unless $auth && @$auth;

    my $connection_class = $result{class};

    my $connection;

    if ($connection_class eq 'Elive::StandardV2::Connection') {
	#
	# exercise a direct connection from Elive main. No preload
	# of connection or entity classes.
	#
        note("connecting: user=$auth->[1], url=$auth->[0]");
	
	is( exception {$connection = Elive::StandardV2::Connection->connect(@$auth)} => undef,
	      "Elive::StandardV2::Connection->connect(...) - lives");
    }
    else {
	eval "require $connection_class";
	die $@ if $@;

	note ("connecting: user=$auth->[1], url=$auth->[0]");

	is( exception {$connection = $connection_class->connect(@$auth)} => undef,
		       "${connection_class}->connect(...) - lives");
	Elive::StandardV2->connection($connection);
    }

    ok($connection, 'got connection');

    BAIL_OUT("unable to connect - aborting further tests")
	unless $t->is_passing;

    isa_ok($connection, $connection_class,'connection')
	or exit(1);

    my $scheduling_manager;
    is ( exception {$scheduling_manager = $connection->scheduling_manager} => undef,
	      '$connection->scheduling_manager - lives');
    isa_ok($scheduling_manager, 'Elive::StandardV2::SchedulingManager','scheduling_manager');
    my $min_version_num = '3.3.2';
    my $max_version_num = '3.3.5';

    ok(my $scheduler_version = $scheduling_manager->version, 'got server version');
    ok(my $scheduler_manager = $scheduling_manager->manager, 'got server manager');

    my ($scheduler_version_num) = ($scheduler_version =~ m{^([\d\.]+)});
    note ("Elluminate Live! manager $scheduler_version_num");
    ok($scheduler_version_num ge $min_version_num, "Elluminate Live! server is $min_version_num or higher");

    my $tested_managers = 'ELM';
    my $manager = $scheduling_manager->manager;

    if ($scheduler_version_num gt $max_version_num
	|| $manager !~ m{^($tested_managers)$}) {
	diag "************************";
	diag "Note: Elluminate Live! server version is ".$scheduler_version_num;
	diag "      This Elive::StandardV2 release ($Elive::StandardV2::VERSION) has been tested against $tested_managers on 3.3.2 - ".$max_version_num;
	diag "      You might want to check CPAN for a more recent version of Elive::StandardV2.";
	diag "************************";
    }

    my $server_configuration;
    is ( exception {$server_configuration = $connection->server_configuration} => undef, 'get server_configuration - lives');
    isa_ok($server_configuration, 'Elive::StandardV2::ServerConfiguration','server_configuration');


    my $server_version;
    is ( exception {$server_version = $connection->server_versions} => undef, 'get server_versions - lives');
    if ($server_version) {
	isa_ok($server_version, 'Elive::StandardV2::ServerVersions','server_versions');

	note 'Elluminate Live! server '.$server_version->versionName.' ('.$server_version->versionId.')';
    }
    else {
	diag "unable to get server versions - are all servers running?";
	$t->skip ("unable to get server version - skipping");
    }

    $connection->disconnect;
}

