#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Elive::SAS' ) || print "Bail out!
";
}

diag( "Testing Elive::SAS $Elive::SAS::VERSION, Perl $], $^X" );
