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

sub test_connection {
    my $class = shift;
    my %opt = @_;

    my $suffix = $opt{suffix} || '';
    my %result;

    my $user = $ENV{'ELIVE_TEST_USER'.$suffix};
    my $pass = $ENV{'ELIVE_TEST_PASS'.$suffix};
    my $url  = $ENV{'ELIVE_TEST_URL'.$suffix};

    $result{auth} = [$url, $user, $pass, type => 'SAS'];

    unless ($opt{noload}) {
	#
	# don't give our test a helping hand, We're
	# testing self load of this module by Elive
	#
	eval {require Elive::Connection::SAS}; die $@ if $@;
    }
    $result{class} = 'Elive::Connection::SAS';

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

1;
