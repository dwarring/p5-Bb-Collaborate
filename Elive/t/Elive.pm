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

sub test_connection {
    my $class = shift;
    my %opt = @_;

    my $suffix = $opt{suffix} || '';
    my %result;

    my $user = $ENV{'ELIVE_TEST_USER'.$suffix};
    my $pass = $ENV{'ELIVE_TEST_PASS'.$suffix};
    my $url  = $ENV{'ELIVE_TEST_URL'.$suffix};

    if (!$opt{only} || $opt{only} eq 'real') {

	if ($user && $pass && $url && $url !~ m{^mock:}i) {
	    $result{auth} = [$url, $user, $pass];
	    unless ($opt{noload}) {
		#
		# don't give our test a helping hand, We're
		# testing self load of this module by Elive
		#
		eval {require Elive::Connection}; die $@ if $@;
	    }
	    $result{class} = 'Elive::Connection';
	}
	else {
	    $result{reason} = 'skipping live tests (set $ELIVE_TEST_{USER|PASS|URL}'.$suffix.' to enable)';
	}
    }

    if (!$result{auth} && (!$opt{only} || $opt{only} eq 'mock')) {
	delete $result{reason};

	unless ($user && $pass && $url && $url =~ m{^mock:}i) {

	    $user = 'test_user'.$suffix;
	    $pass = 'test_pass'.$suffix;
	    $url  = 'mock://elive_test_connection'.$suffix;
	}

	$result{auth} = [$url, $user, $pass];
	eval {require t::Elive::MockConnection}; die $@ if $@;
	$result{class} = 't::Elive::MockConnection';
    }

    if ($result{auth} && (my $debug = Elive->debug)) {
	push (@{$result{auth}}, debug => $debug);
    }

    return %result;
}

sub generate_id {
    my @chars = ('a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '_', '-');
    my @p = map {$chars[ sprintf("%d", rand(scalar @chars)) ]} (1.. 6);

    return join('', @p);
}

=head2 a_week_between

    ok(t::Elive::a_week_between($last_week_t, $this_week_t)

A rough test of times being about a week apart. Anything more
precise is going to require time-zone aware date/time calculations
and will introduce some pretty fat build dependencies.

=cut

sub a_week_between {
    my $start = shift;
    my $end = shift;
    my $seconds_in_a_week = 7 * 24 * 60 * 60;
    #
    # just test that the dates are a week apart to within an hour and a
    # half, or so. This should accomodate daylight savings and other
    # adjustments of up to 1.5 hours.
    #
    my $drift = 1.6 * 60 * 60; # a little over 1.5 hours
    my $ok = abs ($end - $start - $seconds_in_a_week) < $drift;

    return $ok;
}

1;
