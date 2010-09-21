#!perl
use warnings; use strict;
use Test::More tests => 4;
use Test::Exception;
use Test::Builder;
use version;

use lib '.';
use t::Elive::SAS;

use Elive::SAS::SessionAttendance;

our $t = Test::Builder->new;
our $class = 'Elive::SAS::SessionAttendance' ;

our $connection;

use Carp;
$SIG{__DIE__} = \&Carp::confess;

SKIP: {

    my $skippable = 4;

    my %result = t::Elive::SAS->test_connection();
    my $auth = $result{auth};

   skip ($result{reason} || 'skipping live tests', $skippable)
	unless $auth && @$auth;

    my $connection_class = $result{class};
    $connection = $connection_class->connect(@$auth);
    Elive::SAS->connection($connection);

    my $good_som;
    {
	lives_ok( sub{$good_som = $connection->call('getSchedulingManager')}, 'legitimate soap call - lives...');
    }

    lives_ok( sub{Elive->_check_for_errors($good_som)}, '...and lives when checked');

   my $bad_som;
    {
	lives_ok( sub{$bad_som = $connection->call('unknownCommandXXX')}, 'call to unknown adapter - intially lives...');
    }

    dies_ok( sub{Elive->_check_for_errors($bad_som)}, '...but dies when checked');
}

Elive->disconnect;

