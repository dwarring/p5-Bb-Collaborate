#!perl
use warnings; use strict;
use Test::More tests => 6;
use Test::Exception;
use Test::Builder;
use version;

use lib '.';
use t::Elive::StandardV2;

use Elive::StandardV2::Connection;
use Elive::StandardV2::SessionAttendance;

our $t = Test::Builder->new;
our $class = 'Elive::StandardV2::SessionAttendance' ;

our $connection;

use Carp;
$SIG{__DIE__} = \&Carp::confess;

SKIP: {

    my $skippable = 6;

    my %result = t::Elive::StandardV2->test_connection();
    my $auth = $result{auth};
    my $connection_class = $result{class};

   skip ($result{reason} || 'skipping live tests', $skippable)
	unless $auth && @$auth;

    $connection = $connection_class->connect(@$auth);
    Elive::StandardV2->connection($connection);

    my $password = $connection->pass;

    lives_ok( sub {
	my $c2 = Elive::StandardV2::Connection->connect($connection->url, $connection->user, $password );
	$c2->disconnect;
	     }, 'connect/disconnect with good credentials - lives' );

    dies_ok( sub {
	# add some junk to the password
	my $bad_password =  $password . t::Elive::StandardV2::generate_id();
	Elive::StandardV2::Connection->connect($connection->url, $connection->user, $bad_password )
	     }, 'attempted connect with bad password - dies' );

    my $good_som;
    {
	lives_ok( sub{$good_som = $connection->call('getSchedulingManager')}, 'legitimate soap call - lives...');
    }

    lives_ok( sub{$connection->_check_for_errors($good_som)}, '...and lives when checked');

   my $bad_som;
    {
	local($connection->known_commands->{'unknownCommandXXX'}) = 'r';
	lives_ok( sub{$bad_som = $connection->call('unknownCommandXXX')}, 'call to unknown command - intially lives...');
    }

    dies_ok( sub{$connection->_check_for_errors($bad_som)}, '...but dies when checked');
}

Elive::StandardV2->disconnect;

