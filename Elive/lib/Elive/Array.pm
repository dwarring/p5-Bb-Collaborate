package Elive::Array;
use warnings; use strict;
use Mouse;

use Elive;
use Data::Def::Array;

use base qw{Elive};

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

sub new {
    warn "new: @_";
    return bless($_[1] || [], $_[0]);
}

1;
