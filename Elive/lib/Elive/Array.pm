package Elive::Array;
use warnings; use strict;
use Mouse;

use Elive;
use base qw{Elive};

=head1 NAME

Elive::Array - base class for arrays

=head1 DESCRIPTION

Base class for arrays within entities. E.g. members property of
Elive::Entity::participantList.

=cut

use overload
    '""' =>
    sub {shift->stringify}, fallback => 1;

=head1 METHODS

=cut

=head2 stringify

Stringifies arrays members by joining their sting values with ';'.

=cut

sub stringify {
    my $self = shift;
    my $arr = shift || $self;
    #
    # Rely on sub entities stringifying and sorting correctly
    #
    return join(';', sort map {UNIVERSAL::can($_,'stringify')? $_->stringify: $_} @$arr);
}

=head2 new

   my $array_obj = Elive::Array->new($array_ref);

=cut

sub new {
    return bless($_[1] || [], $_[0]);
}

1;
