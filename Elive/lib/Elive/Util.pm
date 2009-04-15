package Elive::Util;
use warnings; use strict;

use Term::ReadKey;
use Term::ReadLine;
use Scalar::Util;
use Storable;

use UNIVERSAL;

=head1 NAME

Elive::Util - utility functions for Elive

=cut

=head1 METHODS

=cut

=head2 parse_type

   my $att = $my_class->meta->get_attribute_map->{foo};

   my ($primary_type,
       $is_array,
       $is_entity) = Elive::Util::parse_type($att->type_constraint)

Parses an entity property type. Determines whether it is an array and/or
sub-structure.

=cut

sub parse_type {
    my $type = shift;

    #
    # Alternate types returned are returned as an array in some Moose
    # Moose versions. Take first as the primary type.
    #
    $type = $type->[0]
	if (_reftype($type) eq 'ARRAY');

    my $is_array = ($type =~ s{^ArrayRef\[ ([^\]]*) \] $}{$1}x);

    #
    # May also be in the format primary-type[|type2[|type3]]
    #
    ($type) = split(/\|/, $type);

    my $is_struct = $type =~ m{^Elive::(Struct||Entity)(::|$)};
##    my $is_struct = UNIVERSAL::isa($type, 'Elive::Struct');

    return ($type, $is_array, $is_struct);
}

=head2 prompt

    my $password = Elive::Util::prompt('Password: ', password => 1)

Prompt for user input

=cut

sub prompt {

    chomp(my $prompt = shift || 'input:');
    my %opt = @_;

    ReadMode $opt{password}? 2: 1; # Turn off controls keys

    my $input;
    my $n = 0;

    do {
	die "giving up on input of $prompt" if ++$n > 100;
	print $prompt if -t STDIN;
	$input = ReadLine(0);
	return undef unless (defined $input);
	chomp($input);
    } until (defined($input) && length($input));

    ReadMode 0; # Reset tty mode before exiting

    return $input;
}

sub _reftype {
    return Scalar::Util::reftype( shift() ) || '';
}

sub _clone {
    return Storable::dclone(shift);
}

1;
