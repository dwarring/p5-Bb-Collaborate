#!perl
use warnings; use strict;
use Test::More tests => 12;
use Test::Exception;
use version;

use lib '.';
use t::Elive;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Entity::Preload' );
};

my $class = 'Elive::Entity::Preload' ;

SKIP: {

    my %result = t::Elive->auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	10)
	unless $auth && @$auth;

    diag ("connecting: user=$auth->[1], url=$auth->[0]");

    Elive->connect(@$auth);

    ok(my $connection = Elive->connection, 'got connection');
    isa_ok($connection, 'Elive::Connection','connection')
	or exit(1);

    my $login;

    ok ($login = Elive->login, 'got login');
    isa_ok($login, 'Elive::Entity::User','login');
    # case insenstive comparision
    ok(uc($login->loginName) eq uc($auth->[1]), 'username matches login');

    my $server_details;
    my $server_version;

    ok ($server_details = Elive->server_details, 'got server details');
    isa_ok($server_details, 'Elive::Entity::ServerDetails','server_details');
    ok($server_version = $server_details->version, 'got server version');
    diag ('Elluminate Live! version: '.qv($server_version));

    my $version_num = version->new($server_version)->numify;
    ok($version_num >= 9, "Elluminate Live! server is 9.0.0 or higher");

    my $highest_tested_version = 9.005;

    if ($version_num > $highest_tested_version) {
	diag "************************";
	diag "Note: Elluminate Live! server version is ".qv($server_version);
	diag "      This Elive release ($Elive::VERSION) has been tested against v9.0.0 - v9.1.0";
	diag "      You might want to check CPAN for a more recent version of Elive.";
	diag "************************";
    }

    ok(ref($server_details->sessions), 'ServerDetails sessions is a reference');
}

Elive->disconnect;

