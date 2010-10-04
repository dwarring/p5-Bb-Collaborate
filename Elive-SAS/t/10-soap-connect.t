#!perl
use warnings; use strict;
use Test::More tests => 11;
use Test::Exception;

use lib '.';
use t::Elive::SAS;

use Elive::SAS;
# don't 'use' anything here! We're testing Elive's ability to load the
# other required classes (Elive::Connection, Elive::Entity::User etc)

our $t = Test::Builder->new;

SKIP: {

    my %result = t::Elive::SAS->test_connection(noload => 1);
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	11)
	unless $auth && @$auth;

    my $connection_class = $result{class};

    my $connection;

    if ($connection_class eq 'Elive::Connection::SAS') {
	#
	# exercise a direct connection from Elive main. No preload
	# of connection or entity classes.
	#
	diag ("connecting: user=$auth->[1], url=$auth->[0]");
	
	$connection = Elive::SAS->connect(@$auth);
    }
    else {
	eval "require $connection_class";
	die $@ if $@;

	diag ("connecting: user=$auth->[1], url=$auth->[0]");

	$connection = $connection_class->connect(@$auth);
	Elive::SAS->connection($connection);
    }

    ok($connection, 'got connection');
    isa_ok($connection, $connection_class,'connection')
	or exit(1);

    my $scheduling_manager;
    lives_ok (sub {$scheduling_manager = $connection->scheduling_manager},
	      '$connection->scheduling_manager - lives');
    isa_ok($scheduling_manager, 'Elive::SAS::SchedulingManager','scheduling_manager');
    my $min_version_num = '3.3.2';
    my $max_version_num = '3.3.2';

    ok(my $server_version = $scheduling_manager->version, 'got server version');
    ok(my $server_manager = $scheduling_manager->manager, 'got server manager');

    my ($server_version_num) = ($server_version =~ m{^([\d\.]+)});
    diag ("Elluminate Live! manager: $server_version_num version: $server_version_num");
    ok($server_version_num ge $min_version_num, "Elluminate Live! server is $min_version_num or higher");

    my $tested_managers = 'ELM';
    my $manager = $scheduling_manager->manager;

    if ($server_version_num gt $max_version_num
	|| $manager !~ m{^($tested_managers)$}) {
	diag "************************";
	diag "Note: Elluminate Live! server version is ".$server_version_num;
	diag "      This Elive::SAS release ($Elive::SAS::VERSION) has been tested against $tested_managers on 3.3.2 - ".$max_version_num;
	diag "      You might want to check CPAN for a more recent version of Elive::SAS.";
	diag "************************";
    }

    my $server_configuration;
    lives_ok (sub{$server_configuration = $connection->server_configuration}, 'get server_configuration - lives');
    isa_ok($server_configuration, 'Elive::SAS::ServerConfiguration','server_configuration');


    my $server_versions;
    lives_ok (sub{$server_versions = $connection->server_versions}, 'get server_versions - lives');
    isa_ok($server_versions, 'Elive::SAS::ServerVersions','server_versions');

    diag 'server version '.$server_versions->versionName.' ('.$server_versions->versionId.')';

}

Elive->disconnect;

