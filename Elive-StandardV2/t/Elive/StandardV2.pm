package t::Elive::StandardV2;
use warnings; use strict;

=head1 NAME

t::Elive::StandardV2

=head1 DESCRIPTION

Testing support package for Elive::StandardV2

=cut
=head2 auth

locate test authorization from the environment

=cut

use URI;
use Elive::StandardV2;

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
	    $result{auth} = [$url, $user, $pass, type => 'StandardV2'];
	    if (my $debug = Elive::StandardV2->debug) {
		push (@{$result{auth}}, debug => $debug);
	    }
	    eval {require Elive::StandardV2::Connection};
	    die $@ if $@;
	    $result{class} = 'Elive::StandardV2::Connection';
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
