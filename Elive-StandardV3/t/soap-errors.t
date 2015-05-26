#!perl
use warnings; use strict;
use Test::More tests => 6;
use Test::Fatal;

use version;

use lib '.';
use t::Elive::StandardV3;

use Elive::StandardV3::Connection;
use Elive::StandardV3::Session::Attendance;

our $t = Test::More->builder;
our $class = 'Elive::StandardV3::Session::Attendance' ;

our $connection;

use Carp;
$SIG{__DIE__} = \&Carp::confess;

SKIP: {

    my $skippable = 6;

    my %result = t::Elive::StandardV3->test_connection();
    my $auth = $result{auth};
    my $connection_class = $result{class};

   skip ($result{reason} || 'skipping live tests', $skippable)
	unless $auth && @$auth;

    $connection = $connection_class->connect(@$auth);
    Elive::StandardV3->connection($connection);

    my $password = $connection->pass;

    is( exception {
	my $c2 = Elive::StandardV3::Connection->connect($connection->url, $connection->user, $password );
	$c2->disconnect;
	     } => undef, 'connect/disconnect with good credentials - lives' );

    isnt( exception {
	# add some junk to the password
	my $bad_password =  $password . t::Elive::StandardV3::generate_id();
	Elive::StandardV3::Connection->connect($connection->url, $connection->user, $bad_password )
	     } => undef, 'attempted connect with bad password - dies' );

    my $good_som;
    {
	is( exception {$good_som = $connection->call('GetSchedulingManager')} => undef, 'legitimate soap call - lives...');
    }

    is( exception {$connection->_check_for_errors($good_som)} => undef, '...and lives when checked');

   my $bad_som;
    {
	local($connection->known_commands->{'UnknownCommandXXX'}) = 'r';
	is( exception {$bad_som = $connection->call('UnknownCommandXXX')} => undef, 'call to unknown command - intially lives...');
    }

    isnt( exception {$connection->_check_for_errors($bad_som)} => undef, '...but dies when checked');
}

Elive::StandardV3->disconnect;

