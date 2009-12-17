package t::Elive::MockSOM;
use warnings; use strict;

use Class::Accessor;
use base qw{Class::Accessor};

__PACKAGE__->mk_accessors( qw{fault faultstring result paramsout} );

sub _pack_data {
    #
    # _freeze - construct name/value pairs for database inserts or updates
    #
    my $class = shift;
    my $data = shift;

    #
    # Assume a simple scalar is a primary key
    #
    my $adapter = ucfirst($class->entity_name.'Adapter');
    my $pkey = $class->_primary_key;

    if (!ref($data) && @$pkey) {
	return $adapter => {$pkey->[0] => $data};
    }

    die "can't handle packing of arrays yet"
	if ref($data) eq 'ARRAY';

    my %db_data = %$data;

    my @properties = $class->properties;
    my $property_types =  $class->property_types || {};

    foreach (keys %db_data) {

	die "$class: unknown property: $_: expected: @properties"
	    unless exists $property_types->{$_};

	my ($type, $is_array, $is_struct) = Elive::Util::parse_type($property_types->{$_});

	for ($db_data{$_}) {
	    next unless defined;

	    if ($is_struct) {
		my ($adapter, $packed_data) = _pack_data($type, $_);
		$_ = {$adapter => $packed_data};
	    }
	    else {
		for ($is_array? @$_: $_) {
		    
		    $_ = Elive::Util::_freeze($_, $type);

		}
	    }
	}
    }

    my %data_out;

    foreach (keys %db_data) {
	$data_out{ucfirst($_)} = $db_data{$_};
    }

    return $adapter => \%data_out;
}

sub make_result {
    my $class = shift;
    my $entity_class = shift;
    my %data = @_;

    my ($adapter, $packed_data) = _pack_data($entity_class, \%data);

    my $self = bless{}, $class;
    $self->result({$adapter => $packed_data});

    $self;
}

1;
