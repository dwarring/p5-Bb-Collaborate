#!perl -T
use warnings; use strict;
use Test::More tests => 5;
use Test::Exception;
use version;

use lib '.';
use t::Elive;

use Elive;

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	5)
	unless $auth && @$auth;

    my $connection_class = $result{class};

    my $connection = $connection_class->connect(@$auth);
    isa_ok($connection, 'Elive::Connection','connection')
	or exit(1);

    Elive->connection($connection);

    my $good_som;
    {
	lives_ok( sub{$good_som = $connection->call('getServerDetails')}, 'legitimate soap call - lives...');
    }

    lives_ok( sub{$connection->_check_for_errors($good_som)}, '...and lives when checked');

   my $bad_som;
    {
	local($connection->known_commands->{'unknownCommandXXX'}) = 'r';
	lives_ok( sub{$bad_som = $connection->call('unknownCommandXXX')}, 'call to unknown command - intially lives...');
    }

    dies_ok( sub{$connection->_check_for_errors($bad_som)}, '...but dies when checked');


}

Elive->disconnect;

