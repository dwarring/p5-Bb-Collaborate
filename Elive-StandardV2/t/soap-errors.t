#!perl
use warnings; use strict;
use Test::More tests => 6;
use Test::Fatal;
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

    is( exception {
	my $c2 = Elive::StandardV2::Connection->connect($connection->url, $connection->user, $password );
	$c2->disconnect;
	     } => undef, 'connect/disconnect with good credentials - lives' );

    isnt( exception {
	# add some junk to the password
	my $bad_password =  $password . t::Elive::StandardV2::generate_id();
	Elive::StandardV2::Connection->connect($connection->url, $connection->user, $bad_password )
	     } => undef, 'attempted connect with bad password - dies' );

    my $good_som;
    {
	is( exception {$good_som = $connection->call('getSchedulingManager')} => undef, 'legitimate soap call - lives...');
    }

    is( exception {$connection->_check_for_errors($good_som)} => undef, '...and lives when checked');

   my $bad_som;
    {
	local($connection->known_commands->{'unknownCommandXXX'}) = 'r';
	is( exception {$bad_som = $connection->call('unknownCommandXXX')} => undef, 'call to unknown command - intially lives...');
    }

    isnt( exception {$connection->_check_for_errors($bad_som)} => undef, '...but dies when checked');
}

Elive::StandardV2->disconnect;

