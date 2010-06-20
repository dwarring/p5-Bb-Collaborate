package Elive::Util;
use warnings; use strict;

use Term::ReadKey;
use Term::ReadLine;
use IO::Interactive;
use Scalar::Util;
use Storable;
require UNIVERSAL;
use YAML;

=head1 NAME

Elive::Util - Utility functions for Elive

=cut

=head1 METHODS

=cut

=head2 parse_type

   my $att = $my_class->meta->get_attribute->(foo);

   my ($primary_type,
       $is_array,
       $is_entity) = Elive::Util::parse_type($att->type_constraint)

Parses an entity property type. Determines whether it is an array and/or
sub-structure.

=cut

sub parse_type {
    my $type = shift;

    #
    # Elive::Array::
    #
    ($type) = split(/[ \| \] ]/x, $type);

    my $is_array = ($type =~ m{^Elive::Array}x);

    if ($is_array) {

	$type = $type->element_class || 'Str';

    }

    my $is_struct = $type =~ m{^Elive::(Struct||Entity)(::|$)}x;

    my $is_ref = $is_array || $is_struct || $type =~ m{^Ref}x;

    return ($type, $is_array, $is_struct, $is_ref);
}

#
# freezing of elementry datatypes
#

sub _freeze {
    my ($val, $type) = @_;

    for ($val) {

	if (!defined) {

	    warn "undefined value of type $type\n"
	}
	else {
	    $_ = string($_, $type);
	    my $raw_val = $_;

	    if ($type =~ m{^Bool}i) {

		#
		# DBize boolean flags..
		#
		$_ =  $_ ? 'true' : 'false';
	    }
	    elsif ($type =~ m{^(Str|enum)}i) {
		#
		# l-r trim
		#
		s{^ \s* (.*?) \s* $}{$1}x;
		$_ = lc if $type =~ m{^enum};
	    }
	    elsif ($type =~ m{^(Int|HiResDate)}i) {
		
		$_ = _tidy_decimal($_);
		
	    }
	    elsif ($type =~ m{^Ref}i) {
		die "freezing of datatype $type: not implemented\n";
	    }

	    die "unable to convert $raw_val to $type\n"
		unless defined;
	}
    }

    return $val;
}

#
# thawing of elementry datatypes
#

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
	elsif ($type =~ m{^(Str|enum)}i) {
	    #
	    # l-r trim
	    #
	    s{^ \s* (.*?) \s* $}{$1}x;
	    $_ = lc if $type =~ m{^enum};
	}
	elsif ($type =~ m{^Int|HiResDate}i) {

	    $_ = _tidy_decimal($_);

	}
	elsif ($type =~ m{^Ref}i) {
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
    my $i = shift;;
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
            (\d+?) # number - retained
            $}
	    {$1$2}x;

    #
    # reduce -0 => 0
    $i = 0 if ($i eq '-0');

    #
    # sanity check.
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
    my ($prompt,%opt) = @_;

    chomp($prompt ||= 'input:');

    ReadMode $opt{password}? 2: 1; # Turn off controls keys

    my $input;
    my $n = 0;

    do {
	die "giving up on input of $prompt" if ++$n > 100;
	print $prompt if IO::Interactive::is_interactive();
	$input = ReadLine(0);
	return
	    unless (defined $input);
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

#
# Hex encoding/decoding. Use for data streaming. E.g. upload & download
# of preload data.
#

sub _hex_decode {
    my $data = shift;

    return
	unless defined $data;

    $data = '0'.$data
	unless length($data) % 2 == 0;

    my ($non_hex_char) = ($data =~ m{([^0-9a-f])}ix);

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

    print Elive::Util::string($myscalar);
    print Elive::Util::string($myobj);
    print Elive::Util::string($myref, $datatype);

Return a string for an object.

=over 4

=item

If it's a simple scalar, just pass the value back.

=item

If it's an object use the C<stringify> method.

=item

If it's a reference, resolve datatype to a class, and use its
C<stringify> method.

=back

=cut

sub string {
    my $obj = shift;
    my $data_type = shift;

    for ($obj) {

	my $reftype =  _reftype($_);

	return $_
	    unless $reftype;

	return join(';', sort map {string($_, $data_type)} @$_)
	    if $reftype eq 'ARRAY';

	return $_->stringify
	    if (Scalar::Util::blessed($_) && $_->can('stringify'));

	if ($data_type) {
	    my ($type, $is_array, $is_struct) = parse_type($data_type);
	    return $type->stringify($_)
		if ($is_struct && $type->can('stringify'));
	}
    }

    #
    # Nothing else worked; dump it.
    #
    return YAML::Dump($obj);
}

1;
