#!perl -T
use warnings; use strict;
use Test::More tests => 10;
use Test::Exception;
use version;

use lib '.';
use t::Elive;

use Elive;
# don't 'use' anything here! We're testing Elive's ability to load the
# other required classes (Elive::Connection, Elive::Entity::User etc)

our $t = Test::Builder->new;

SKIP: {

    my %result = t::Elive->test_connection(noload => 1);
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 9)
	unless $auth && @$auth;

    my $connection_class = $result{class};

    my $connection;

    if ($connection_class eq 'Elive::Connection::SDK') {
	#
	# exercise a direct connection from Elive main. No preload
	# of connection or entity classes.
	#
	diag ("connecting: user=$auth->[1], url=$auth->[0]");
	
	$connection = Elive->connect(@$auth);
    }
    else {
	eval "require $connection_class";
	die $@ if $@;

	diag ("connecting: user=$auth->[1], url=$auth->[0]");

	$connection = $connection_class->connect(@$auth);
	Elive->connection($connection);
    }

    ok($connection, 'got connection');
    isa_ok($connection, $connection_class,'connection')
	or exit(1);

    my $login;
    ok ($login = Elive->login, 'got login');
    isa_ok($login, 'Elive::Entity::User','login');
    # case insensitive comparision
    my $login_name = $login->loginName;
    ok(uc($login_name) eq uc($auth->[1]), 'username matches login');

    my $login_refetch;
    my $server_details;
    my $server_version;

    my $min_version =  '9.0.0';
    my $min_version_num = version->new($min_version)->numify;

    my $min_recommended_version =  '9.5.0';
    my $min_recommended_version_num = version->new($min_recommended_version)->numify;

    my $max_version =  '10.0.1';
    my $max_version_num = version->new($max_version)->numify;

    ok ($server_details = Elive->server_details, 'got server details');
    isa_ok($server_details, 'Elive::Entity::ServerDetails','server_details');
    ok($server_version = $server_details->version, 'got server version');
    diag ('Elluminate Live! version: '.qv($server_version));

    my $server_version_num = version->new($server_version)->numify;
    ok($server_version_num >= $min_version_num, "Elluminate Live! server is $min_version or higher");

    if ($server_version_num < $min_version_num) {
	diag "************************";
	diag "Note: this Elluminate Live! server version is ".qv($server_version);
	diag "      This Elive release ($Elive::VERSION) supports Elluminate Live! ".qv($min_version)." - ".qv($max_version);
        diag "      The recommended version is $min_recommended_version or better";
	diag "************************";
    }
    elsif ($server_version_num < $min_recommended_version_num) {
	diag "************************";
	diag "Note: this Elluminate Live! server version is ".qv($server_version);
	diag "      A number Elive classes are not fully operational, including:";
	diag "        * Elive::Entity::Session";
	diag "        * Elive::Entity::Recording";
	diag "        * Elive::Entity::Group";
        diag "      The recommended version is $min_recommended_version or better";
	diag "************************";
    }
    elsif ($server_version_num > $max_version_num) {
	diag "************************";
	diag "Note: this Elluminate Live! server version is ".qv($server_version);
	diag "      This Elive release ($Elive::VERSION) has been tested against ".qv($min_version)." - ".qv($max_version);
	diag "      You might want to check CPAN for a more recent version of Elive.";
	diag "************************";
    }

    ok(do {
	my $sessions = $server_details->sessions;
	!defined $sessions || ref($sessions)
       }, 'ServerDetails sessions - undef or a reference');
}

Elive->disconnect;

