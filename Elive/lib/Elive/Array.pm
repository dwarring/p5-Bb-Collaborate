package Elive::Array;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive;
use base qw{Elive};

__PACKAGE__->mk_classdata('element_class');

coerce 'Elive::Array' => from 'Str'
          => via {
	      my $a = [ split(';') ];
	      bless ($a,'Elive::Array');
	      $a;
          };

coerce 'Elive::Array' => from 'ArrayRef[Str]'
          => via {
	      bless ($_,'Elive::Array');
          };

require UNIVERSAL;

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
    my $arr  = shift || $self;
    my $type = shift || $self->element_class;

    return Elive::Util::string($arr, $type);
}

=head2 new

   my $array_obj = Elive::Array->new($array_ref);

=cut

sub new {
    return bless($_[1] || [], $_[0]);
}

=head2 add 

    $group->members->add('111111', '222222');

Add elements to an array.

=cut

sub add {
    my $self = shift;

    my @elems = grep {defined} @_;

    if (my $element_class = $self->element_class) {
	foreach (@elems) {
	    $_ = $element_class->new($_)
		unless Scalar::Util::blessed($_);
	}
    }

    push (@$self, @elems);
}

1;
