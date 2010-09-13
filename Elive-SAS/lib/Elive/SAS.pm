package Elive::SAS;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive '0.74_1';

extends 'Elive::DAO';

=head1 NAME

    Elive::SAS - Base class for Elive Standard Bridge V2 (SAS) Entities

=head1 VERSION

Version 0.00_1

=cut

our $VERSION = '0.00_1';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Elive::SAS;

    my $foo = Elive::SAS->new();
    ...

=head1 DESCRIPTION

Implements Elive Standard Bridge V2 (SAS) API bindings

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

=head1 SUBROUTINES/METHODS

=head2 insert

=cut

sub insert {
    my ($class, $data, %opt) = @_;

    $opt{adapter} ||= 'set'.$class->entity_name;

    return $class->SUPER::insert($data, %opt);
}

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-elive-sas at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Elive-SAS>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Elive::SAS


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Elive-SAS>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Elive-SAS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Elive-SAS>

=item * Search CPAN

L<http://search.cpan.org/dist/Elive-SAS/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 David Warring.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
