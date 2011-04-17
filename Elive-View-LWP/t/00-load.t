#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Elive::View::LWP' ) || print "Bail out!
";
}

diag( "Testing Elive::View::LWP $Elive::View::LWP::VERSION, Perl $], $^X" );
