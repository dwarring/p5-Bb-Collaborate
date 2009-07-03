package t::Elive;
use warnings; use strict;
#
# auth - locate test authorization from the environment
#
sub auth {
    my $class = shift;
    my %opt = @_;

    my $suffix = $opt{suffix} || '';

    my $user = $ENV{'ELIVE_TEST_USER'.$suffix};
    my $pass = $ENV{'ELIVE_TEST_PASS'.$suffix};
    my $url  = $ENV{'ELIVE_TEST_URL'.$suffix};

    my %result;

    if ($user && $pass && $url) {
	$result{auth} = [$url, $user, $pass];
    }
    else {
	$result{reason} = 'need to set $ELIVE_TEST_{USER|PASS|URL}'.$suffix;
    }

    return %result;
}

1;
