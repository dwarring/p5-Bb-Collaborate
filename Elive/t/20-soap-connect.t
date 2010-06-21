#!perl
use warnings; use strict;
use Test::More tests => 10;
use Test::Exception;
use version;

use lib '.';
use t::Elive;

use Elive;
use Elive::Entity::User;
use Elive::Entity::ServerDetails;

our $t = Test::Builder->new;

SKIP: {

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	9)
	unless $auth && @$auth;

    my $connection_class = $result{class};
    diag ("connecting: user=$auth->[1], url=$auth->[0]");

    my $connection = $connection_class->connect(@$auth);
    ok($connection, 'got connection');
    isa_ok($connection, 'Elive::Connection','connection')
	or exit(1);

    Elive->connection($connection);

    my $login;
    ok ($login = Elive->login, 'got login');
    isa_ok($login, 'Elive::Entity::User','login');
    # case insensitive comparision
    my $login_name = $login->loginName;
    ok(uc($login_name) eq uc($auth->[1]), 'username matches login');

    my $login_refetch;
    my $server_details;
    my $server_version;

    ok ($server_details = Elive->server_details, 'got server details');
    isa_ok($server_details, 'Elive::Entity::ServerDetails','server_details');
    ok($server_version = $server_details->version, 'got server version');
    diag ('Elluminate Live! version: '.qv($server_version));

    my $server_version_num = version->new($server_version)->numify;
    ok($server_version_num >= 9, "Elluminate Live! server is 9.0.0 or higher");

    my $tested_version = '10.0.0';
    my $tested_version_num = version->new($tested_version)->numify;

    if ($server_version_num > $tested_version_num) {
	diag "************************";
	diag "Note: Elluminate Live! server version is ".qv($server_version);
	diag "      This Elive release ($Elive::VERSION) has been tested against v9.0.0 - ".qv($tested_version);
	diag "      You might want to check CPAN for a more recent version of Elive.";
	diag "************************";
    }

    ok(do {
	my $sessions = $server_details->sessions;
	!defined $sessions || ref($sessions)
       }, 'ServerDetails sessions - undef or a reference');
}

Elive->disconnect;

