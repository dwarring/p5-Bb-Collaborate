#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Elive::WWW::Session' ) || print "Bail out!
";
}

diag( "Testing Elive::WWW::Session $Elive::WWW::Session::VERSION, Perl $], $^X" );
