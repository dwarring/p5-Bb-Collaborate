package Elive::Util;
use warnings; use strict;

use Term::ReadKey;
use Term::ReadLine;
use Scalar::Util;
use Storable;

use UNIVERSAL;

=head1 NAME

Elive::Util - Utility functions for Elive

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
    # ArrayRef[Elive::Entity::User]
    #
    ($type) = split(/[ \| \] ]/x, $type);
    my $is_array = ($type =~ s{^ArrayRef\[}{}x);

    my $is_struct = $type =~ m{^Elive::(Struct||Entity)(::|$)};
##    my $is_struct = UNIVERSAL::isa($type, 'Elive::Struct');

    return ($type, $is_array, $is_struct);
}

sub _freeze {
    my ($val, $type, $context) = @_;

    for ($val) {
	if ($type =~ m{^Bool}i) {

	    #
	    # DBize boolean flags..
	    #
	    $_ =  $_ ? 'true' : 'false'
		if defined;
	}
	elsif ($type =~ m{^Int}i) {
	    
	    $_ = _tidy_decimal($_)
		if defined;
	}
    }

    warn "undefined value of type $type"
	unless defined $val;

    return $val;
}

sub _thaw {
    my ($val, $type) = @_;

    return unless defined $val;

    for ($val) {

	if ($type =~ m{^Bool}i) {
	    #
	    # Perlise boolean flags..
	    #
	    $_ = m{true}i ? 1 : 0;
	}
	elsif ($type =~ m{^(Str|Enum)}i) {
	    #
	    # l-r trim
	    #
	    s{^ \s* (.*?) \s* $}{$1}x;
	}
	elsif ($type =~ m{^Int}i) {

	    $_ = _tidy_decimal($_);

	}
	else {
	    die "unknown type: $type";
	}
    }

    return $val;
}


#
# _tidy_decimal(): general cleanup and normalisation of an integer.
#               used to clean up numbers for data storage or comparison

sub _tidy_decimal {
    my $i = $_[0];
    #
    # well a number really. don't convert or sprintf etc
    # to avoid overflow. Just normalise it for potential
    # string comparisons

    #
    # l-r trim
    #
    $i =~ s{^ \s* (.*?) \s* $}{$1}x;

    #
    # non number => undef
    #
    return
	unless $i =~ m{^[+-]?\d+$};

    #
    # remove any leading zeros:
    # +000123 => 123
    # -00045 => -45
    # -000 => 0
    #

    $i =~ s{^
            \+?    # leading plus -discarded 
            (-?)   # leading minus retained (usually)
            0*     # leading zeros discarded
            (\d+)  # number - retained
            $}
	    {$1$2}x;

    #
    # reduce -0 => 0
    $i = 0 if ($i eq '-0');

    #
    # should get here. just a sanity check.
    #
    die "bad integer: $_[0]"
	unless $i =~ m{^[+-]?\d+$};

    return $i;
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

sub _hex_decode {
    my $data = shift;

    return
	unless defined $data;

    $data = '0'.$data
	unless length($data) % 2 == 0;

    my ($non_hex_char) = ($data =~ m{([^0-9a-f])}i);

    die "non hex character in data: ".$non_hex_char
	if (defined $non_hex_char);
    #
    # Works for simple ascii
    $data =~ s{(..)}{chr(hex($1))}ge;

    return $data;
}

sub _hex_encode {
    my $data = shift;

    $data =~ s{(.)}{sprintf("%02x", ord($1))}ges;

    return $data;
}

=head2 string

Try hard to return the object as a string. If it's a simple scalar fine,
If it's an object, try using the stringify method..

=cut

sub string {
    for ($_[0]) {
	return $_
	    unless _reftype($_);

	return $_->stringify
	    if UNIVERSAL::can($_,'stringify');

	return $_;
    }
}
1;
