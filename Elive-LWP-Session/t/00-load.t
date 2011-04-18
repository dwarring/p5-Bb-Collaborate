#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Elive::LWP::Session' ) || print "Bail out!
";
}

diag( "Testing Elive::LWP::Session $Elive::LWP::Session::VERSION, Perl $], $^X" );
