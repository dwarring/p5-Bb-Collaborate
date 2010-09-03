#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Elive::Sas' ) || print "Bail out!
";
}

diag( "Testing Elive::Sas $Elive::Sas::VERSION, Perl $], $^X" );
