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

coerce 'Elive::Array' => from 'ArrayRef'
          => via {
	      my @a = map {Elive::Util::string($_)} @$_;
	      bless (\@a,'Elive::Array');
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

Serialises array members by joining their string values with ';'.

=cut

sub stringify {
    my $self = shift;
    my $arr  = shift || $self;
    my $type = shift || $self->element_class;

    return join(';', sort map {Elive::Util::string($_, $type)} @$arr)
}

=head2 new

   my $array_obj = Elive::Array->new($array_ref);

=cut

sub new {
    my ($class,$ref) = @_;
    return bless($ref || [], $class);
}

=head2 add 

    $group->members->add('111111', '222222');

Add elements to an array.

=cut

sub add {
    my ($self, @elems) =  @_;

    @elems = (map {Scalar::Util::reftype($_)? $_: split(';')} 
	      grep {defined} @elems);

    if (my $element_class = $self->element_class) {
	foreach (@elems) {
	    $_ = $element_class->new($_)
		unless Scalar::Util::blessed($_);
	}
    }

    push (@$self, @elems);

    return $self;
}

1;
