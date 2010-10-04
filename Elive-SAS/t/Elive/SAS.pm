package t::Elive::SAS;
use warnings; use strict;

=head1 NAME

t::Elive::SAS

=head1 DESCRIPTION

Testing support package for Elive::SAS

=cut
=head2 auth

locate test authorization from the environment

=cut

use URI;

sub test_connection {
    my $class = shift;
    my %opt = @_;

    my $suffix = $opt{suffix} || '';
    my %result;

    my $user = $ENV{'ELIVE_TEST_USER'.$suffix};
    my $pass = $ENV{'ELIVE_TEST_PASS'.$suffix};
    my $url  = $ENV{'ELIVE_TEST_URL'.$suffix};

    if ($url) {
	my $uri_obj = URI->new($url, 'http');
	my $userinfo = $uri_obj->userinfo; # credentials supplied in URI

	if ($userinfo) {
	    my ($uri_user, $uri_pass) = split(':', $userinfo, 2);
	    $user ||= URI::Escape::uri_unescape($uri_user);
	    $pass ||= URI::Escape::uri_unescape($uri_pass)
		if $uri_pass;
	}

	if ($user && $pass && $url !~ m{^mock:}i) {
	    $result{auth} = [$url, $user, $pass, type => 'SAS'];
	    if (my $debug = Elive->debug) {
		push (@{$result{auth}}, debug => $debug);
	    }
	    eval {require Elive::Connection::SAS};
	    die $@ if $@;
	    $result{class} = 'Elive::Connection::SAS';
	}
    }
    else {
	$result{reason} = 'skipping live tests (set $ELIVE_TEST_{USER|PASS|URL}'.$suffix.' to enable)';
    }

    return %result;
}

sub generate_id {
    my @chars = ('a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '_', '-');
    my @p = map {$chars[ sprintf("%d", rand(scalar @chars)) ]} (1.. 6);

    return join('', @p);
}

1;
