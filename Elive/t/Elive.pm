package t::Elive;
use warnings; use strict;

use Elive;
use t::Elive::MockConnection;

=head1 NAME

t::Elive

=head1 DESCRIPTION

Testing support package for Elive

=cut
=head2 auth

locate test authorization from the environment

=cut

sub test_connection {
    my $class = shift;
    my %opt = @_;

    my $suffix = $opt{suffix} || '';
    my %result;

    if (!$opt{only} || $opt{only} eq 'real') {
	my $user = $ENV{'ELIVE_TEST_USER'.$suffix};
	my $pass = $ENV{'ELIVE_TEST_PASS'.$suffix};
	my $url  = $ENV{'ELIVE_TEST_URL'.$suffix};

	if ($user && $pass && $url) {
	    $result{auth} = [$url, $user, $pass];
	    $result{class} = 'Elive::Connection';
	}
	else {
	    $result{reason} = 'need to set $ELIVE_TEST_{USER|PASS|URL}'.$suffix;
	}
    }

    if (!$result{auth} && (!$opt{only} || $opt{only} eq 'mock')) {
	delete $result{reason};

	my $user = 'test_user'.$suffix;
	my $pass = 'test_pass'.$suffix;
	my $url  = 'http://elive_mock_connection'.$suffix;
	$result{auth} = [$url, $user, $pass];
	$result{class} = 't::Elive::MockConnection';
    }

    if ($result{auth} && (my $debug = Elive->debug)) {
	push (@{$result{auth}}, debug => $debug);
    }

    return %result;
}

1;
