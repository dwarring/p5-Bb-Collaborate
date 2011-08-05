package Elive::Array;
use warnings; use strict;
use Carp;
Carp::cluck "Class ".__PACKAGE__." is depreciated - please use Elive::DAO::Array\n"
    unless $0 && $0 =~ m{pod.*\.t$};

use parent qw{Elive::DAO::Array};

=head1 NAME

ELive::Array

=head1 DESCRIPTION

DEPRECIATED - please use L<Elive::DAO::Array>

=cut

1;
