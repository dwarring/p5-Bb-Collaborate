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

    );

__PACKAGE__->mk_classdata(known_adapters => \%KnownAdapters);

1;
