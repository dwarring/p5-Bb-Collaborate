package Elive::SAS;
use warnings; use strict;
use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::DAO';

=head1 NAME

    Elive::SAS - Base class for Elive Standard Bridge V2 (SAS) Entities

=head1 DESCRIPTION

Implements Elive Standard Bridge V2 (SAS) calls and entities.

=cut

our %KnownAdapters = (

        getSchedulingManager => 'r',

        listSession => 'r',

        setSession => 'cu',

    );

__PACKAGE__->mk_classdata(known_adapters => \%KnownAdapters);

#
# Normalise our data and reconstruct arrays.
#
# See t/05-entity-unpack.t for examples and further explanation.
#

sub _get_results {
    my $class = shift;
    my $som = shift;

    my $result = $som->result;

    return $result
	? Elive::Util::_reftype($result) eq 'ARRAY'
	? $result : [$result]
	: [];
}

sub insert {
    my ($class, $data, %opt) = @_;

    $opt{adapter} ||= 'set'.$class->entity_name;

    return $class->SUPER::insert($data, %opt);
}

1;
