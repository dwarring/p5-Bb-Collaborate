package Elive::Util;
use warnings; use strict;

use Term::ReadKey;
use Term::ReadLine;
use Scalar::Util;
use Storable;

=head1 NAME

Elive::Util - utility functions for Elive

=cut

=head2 parse_type

   my $att = $my_class->meta->get_attribute_map->{foo};

   my ($is_array,
       $is_entity) = Elivey::Util::parse_type($att->type_constraint)

Parses an entity property type. Determines whether it is an array and/or
sub-structure.

=cut

sub parse_type {
    my $type = shift;

    my $is_array = ($type =~ s{^ArrayRef\[(.*?)\]$}{$1})
	||  UNIVERSAL::isa($type, 'Elive::Array');

    my $is_data = UNIVERSAL::isa($type, 'Elive::Struct')
	|| $is_array;

    return ($type, $is_array, $is_data);
}

=head2 prompt

    my $password = Elive::Util::prompt('Password: ', password =>1)

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
