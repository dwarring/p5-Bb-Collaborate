package Elive::Array;
use warnings; use strict;

use Mouse;

use Elive;
use base qw{Elive};

use UNIVERSAL;

=head1 NAME

Elive::Array - Base class for arrays

=head1 DESCRIPTION

Base class for arrays within entities. E.g. members property of
Elive::Entity::participantList.

=cut

=head1 METHODS

=cut

=head2 stringify

Stringifies arrays members by joining their sting values with ';'.

=cut

sub stringify {
    my $self = shift;

    my $class = ref($self) || $self;
    my $arr = shift || $self;
    #
    # Rely on sub entities stringifying and sorting correctly
    #
    my $string = join(';', sort map {Elive::Util::string($_)} @$arr);

##    use YAML; warn YAML::Dump({class => $class, data => $arr});
##    warn "string: $string";

    return $string;
}

=head2 new

   my $array_obj = Elive::Array->new($array_ref);

=cut

sub new {
    return bless($_[1] || [], $_[0]);
}

1;
