#!perl
use warnings; use strict;
use Test::More tests => 2;
use Test::Exception;

use lib '.';
use t::Elive::SAS;

use Elive::SAS;

SKIP: {

    my %result = t::Elive::SAS->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	2)
	unless $auth && @$auth;

    my $connection = Elive::SAS->connect(@$auth);

    my $server_configuration;
    lives_ok (sub{$server_configuration = $connection->server_configuration}, 'get server_configuration - lives');
    isa_ok($server_configuration, 'Elive::SAS::ServerConfiguration','server_configuration');

    diag "boundaryTime: ".$server_configuration->boundaryTime;
}

Elive->disconnect;

