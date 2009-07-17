package t::Elive;
use warnings; use strict;

=head1 NAME

t::Elive

=head1 DESCRIPTION

Testing support package for Elive

=cut

=head2 auth

locate test authorization from the environment

=cut

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
