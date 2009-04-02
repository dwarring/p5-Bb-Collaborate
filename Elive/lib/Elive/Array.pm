package Elive::Array;
use warnings; use strict;

use Elive;
use Data::Def::Array;

use base qw{Elive Data::Def::Array};

use overload
    '""' =>
    sub {shift->stringify}, fallback => 1;

sub stringify {
    my $self = shift;
    my $arr = shift || $self;
    #
    # Rely on sub entities stringifying and sorting correctly
    #
    return join(';', sort map {UNIVERSAL::can($_,'stringify')? $_->stringify: $_} @$arr);
}

1;
